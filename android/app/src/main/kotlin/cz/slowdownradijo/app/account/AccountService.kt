package cz.slowdownradijo.app.account

import android.app.Activity
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import cz.slowdownradijo.app.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.IDTokenProvider
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Instant
import java.time.OffsetDateTime

/**
 * The listener's account: Apple, Google or an e-mail code, the nickname, the DJ link,
 * signing out and deleting the account. As `AccountService.swift`.
 *
 * Signing in on a phone that already has an anonymous stats user links the new sign-in
 * to that user, so the stats stay. Only when the e-mail / Apple ID / Google account
 * already belongs to another account does the phone switch to that account.
 *
 * Apple on Android goes through Apple's web sign-in in a browser tab, which comes back
 * to `slowdownradijo://auth` ([handleDeeplinkError] for the failures).
 */
class AccountService(
    private val supabase: SupabaseClient,
    private val sessions: SupabaseSessionProvider,
    private val scope: CoroutineScope,
) {
    /** What `chat_me()` returns (backend/supabase/sql/020_chat.sql). */
    @Serializable
    data class Me(
        @SerialName("user_id") val userId: String,
        val nickname: String? = null,
        @SerialName("nickname_next_change_at") val nicknameNextChangeAtText: String? = null,
        val role: String = "listener",
        @SerialName("host_id") val hostId: String? = null,
        @SerialName("host_name") val hostName: String? = null,
        @SerialName("is_moderator") val isModerator: Boolean = false,
        @SerialName("muted_until") val mutedUntilText: String? = null,
        val blocked: Boolean = false,
    ) {
        val nicknameNextChangeAt: Instant? get() = nicknameNextChangeAtText?.let(::parseIso)
        val mutedUntil: Instant? get() = mutedUntilText?.let(::parseIso)
        /** The name the listener writes under: the DJ name or the nickname. */
        val chatName: String? get() = hostName ?: nickname
        val isHost: Boolean get() = hostId != null
    }

    enum class SignInMethod { APPLE, GOOGLE, EMAIL }

    sealed interface State {
        data object Loading : State
        /** No permanent account (maybe an anonymous stats user). */
        data object SignedOut : State
        /** Signed in; [me] is null until `chat_me()` answered (offline). */
        data class SignedIn(val method: SignInMethod?, val email: String?, val me: Me?) : State
    }

    /** Where an e-mail code was sent; [linksAnonymousUser]: it adds the e-mail to this phone's anonymous user. */
    data class EmailCodeRequest(val email: String, val linksAnonymousUser: Boolean)

    enum class NicknameCheck { OK, INVALID, RESERVED, TAKEN }

    private val auth get() = supabase.auth
    private val _state = MutableStateFlow<State>(State.Loading)
    val state: StateFlow<State> = _state.asStateFlow()
    val me: Me? get() = (state.value as? State.SignedIn)?.me

    /** Set while Apple's browser sign-in tries to link an anonymous user. */
    @Volatile private var appleLinkPending = false

    /** Starts following the session; call once at launch. */
    fun start() {
        scope.launch {
            runCatching { sessions.migrateLegacySession() }
            auth.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Initializing -> Unit
                    else -> refresh()
                }
            }
        }
    }

    /** Re-reads the account (after sign-in, a nickname change, a mute, …). */
    suspend fun refresh() {
        val user = auth.currentUserOrNull()
        if (user == null || user.isAnonymous == true) {
            _state.value = State.SignedOut
            return
        }
        val method = signInMethod(user)
        val me = runCatching { supabase.postgrest.rpc("chat_me").decodeAs<Me>() }.getOrNull()
            ?: (state.value as? State.SignedIn)?.me
        _state.value = State.SignedIn(method, user.email, me)
    }

    // E-mail code

    suspend fun sendEmailCode(rawEmail: String): EmailCodeRequest = wrap {
        val email = rawEmail.trim().lowercase()
        sessions.migrateLegacySession()
        if (auth.currentUserOrNull()?.isAnonymous == true) {
            try {
                auth.updateUser { this.email = email }
                return@wrap EmailCodeRequest(email, linksAnonymousUser = true)
            } catch (e: AuthRestException) {
                if (e.errorCode != AuthErrorCode.EmailExists) throw e
                // Belongs to an existing account: sign in to it below.
            }
        }
        auth.signInWith(OTP) {
            this.email = email
            createUser = true
        }
        EmailCodeRequest(email, linksAnonymousUser = false)
    }

    suspend fun verifyEmailCode(code: String, request: EmailCodeRequest) {
        val token = code.filter(Char::isDigit)
        try {
            auth.verifyEmailOtp(
                type = if (request.linksAnonymousUser) OtpType.Email.EMAIL_CHANGE else OtpType.Email.EMAIL,
                email = request.email,
                token = token,
            )
        } catch (e: AuthRestException) {
            val status = e.response.status.value
            throw if (status in 400..499 && e.errorCode != AuthErrorCode.OverRequestRateLimit) AccountError.CodeInvalid else AccountError.from(e)
        } catch (e: Exception) {
            throw AccountError.from(e)
        }
        refresh()
    }

    // Google (Credential Manager)

    val isGoogleConfigured: Boolean get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.endsWith(".apps.googleusercontent.com")

    suspend fun signInWithGoogle(activity: Activity) {
        if (!isGoogleConfigured) throw AccountError.ProviderUnavailable
        val (rawNonce, hashedNonce) = makeNonce()
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID).setNonce(hashedNonce).build()
        val credential = try {
            CredentialManager.create(activity).getCredential(activity, GetCredentialRequest.Builder().addCredentialOption(option).build()).credential
        } catch (_: GetCredentialCancellationException) {
            throw AccountError.Cancelled
        } catch (e: Exception) {
            throw AccountError.from(e)
        }
        val idToken = runCatching { GoogleIdTokenCredential.createFrom(credential.data).idToken }.getOrNull()
            ?: throw AccountError.Unknown("google_no_token")
        signInWithIdToken(Google, idToken, rawNonce)
    }

    // Apple (web sign-in in a browser tab)

    suspend fun signInWithApple() = wrap {
        sessions.migrateLegacySession()
        if (auth.currentUserOrNull()?.isAnonymous == true) {
            appleLinkPending = true
            auth.linkIdentity(Apple)
        } else {
            appleLinkPending = false
            auth.signInWith(Apple)
        }
    }

    /**
     * A failed return from Apple's web sign-in (`handleDeeplinks`' onError). If the Apple
     * ID already belongs to another account, sign in to that account instead.
     */
    fun handleDeeplinkError(error: Throwable) {
        val wasLinking = appleLinkPending
        appleLinkPending = false
        val alreadyExists = (error as? AuthRestException)?.errorCode == AuthErrorCode.IdentityAlreadyExists ||
            error.message?.contains("identity_already_exists") == true
        if (wasLinking && alreadyExists) scope.launch { runCatching { auth.signInWith(Apple) } }
    }

    // Shared

    private suspend fun signInWithIdToken(provider: IDTokenProvider, idToken: String, rawNonce: String?) {
        wrap {
            sessions.migrateLegacySession()
            if (auth.currentUserOrNull()?.isAnonymous == true) {
                try {
                    auth.linkIdentityWithIdToken(provider, idToken) { nonce = rawNonce }
                } catch (e: AuthRestException) {
                    if (e.errorCode != AuthErrorCode.IdentityAlreadyExists) throw e
                    auth.signInWith(IDToken) { this.idToken = idToken; this.provider = provider; nonce = rawNonce }
                }
            } else {
                auth.signInWith(IDToken) { this.idToken = idToken; this.provider = provider; nonce = rawNonce }
            }
        }
        refresh()
    }

    // Nickname, DJ, account

    suspend fun setNickname(nickname: String) = wrap {
        val me = supabase.postgrest.rpc("set_nickname", buildJsonObject { put("p_nickname", nickname) }).decodeAs<Me>()
        (state.value as? State.SignedIn)?.let { _state.value = it.copy(me = me) }
    }

    suspend fun checkNickname(nickname: String): NicknameCheck = wrap {
        val answer = supabase.postgrest.rpc("nickname_available", buildJsonObject { put("p_nickname", nickname) })
            .decodeAs<kotlinx.serialization.json.JsonElement>().jsonPrimitive.content
        when (answer) {
            "ok" -> NicknameCheck.OK
            "nickname_reserved" -> NicknameCheck.RESERVED
            "nickname_taken" -> NicknameCheck.TAKEN
            else -> NicknameCheck.INVALID
        }
    }

    /** A DJ opened their invite link (`https://slowdownradijo.cz/dj/<code>`). */
    suspend fun claimHostInvite(code: String) = wrap {
        val me = supabase.postgrest.rpc("claim_host_invite", buildJsonObject { put("p_code", code) }).decodeAs<Me>()
        (state.value as? State.SignedIn)?.let { _state.value = it.copy(me = me) }
    }

    /** Signs out on this phone; stats start again under a new anonymous user. */
    suspend fun signOut() {
        runCatching { auth.signOut() }
        runCatching { auth.clearSession() }
        _state.value = State.SignedOut
    }

    /** Deletes the account; chat messages stay as "Smazaný účet". */
    suspend fun deleteAccount() {
        wrap { supabase.postgrest.rpc("delete_my_account") }
        signOut()
    }

    private suspend fun <T> wrap(block: suspend () -> T): T = try {
        block()
    } catch (e: Exception) {
        throw AccountError.from(e)
    }

    private fun signInMethod(user: UserInfo): SignInMethod? {
        val providers = user.identities.orEmpty().map { it.provider }
        return when {
            "apple" in providers -> SignInMethod.APPLE
            "google" in providers -> SignInMethod.GOOGLE
            "email" in providers || user.email != null -> SignInMethod.EMAIL
            else -> null
        }
    }

    companion object {
        /** A random nonce and its SHA-256 (the hash goes to Google, the raw value to Supabase). */
        fun makeNonce(): Pair<String, String> {
            val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val raw = bytes.joinToString("") { "%02x".format(it) }
            val hashed = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray()).joinToString("") { "%02x".format(it) }
            return raw to hashed
        }

        fun parseIso(text: String): Instant? = runCatching { OffsetDateTime.parse(text).toInstant() }.getOrNull()
            ?: AccountError.parseDate(text)
    }
}
