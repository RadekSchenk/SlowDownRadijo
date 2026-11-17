package cz.slowdownradijo.app.account

import android.content.Context
import android.content.SharedPreferences
import com.russhwolf.settings.SharedPreferencesSettings
import io.github.jan.supabase.auth.SettingsCodeVerifierCache
import io.github.jan.supabase.auth.SettingsSessionManager
import cz.slowdownradijo.app.data.RemoteHistoryService
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.plugins.HttpRequestTimeoutException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.IOException
import kotlin.time.Clock
import kotlin.time.Duration.Companion.seconds

/**
 * The app's one Supabase client: accounts, the chat and the stats session. As
 * `AppSupabase.swift`. The session is kept in the app's own preferences file
 * (`supabase-auth`), so it doesn't depend on the library's start-up initializer.
 */
fun createAppSupabase(context: Context): SupabaseClient {
    val settings = SharedPreferencesSettings(context.getSharedPreferences("supabase-auth", Context.MODE_PRIVATE))
    return createSupabaseClient(
        supabaseUrl = "https://toqoqrshyutyezoyxvlj.supabase.co",
        supabaseKey = RemoteHistoryService.ANON_KEY,
    ) {
        install(Auth) {
            // Apple's web sign-in and the e-mail link come back to slowdownradijo://auth.
            scheme = "slowdownradijo"
            host = "auth"
            flowType = FlowType.PKCE
            sessionManager = SettingsSessionManager(settings)
            codeVerifierCache = SettingsCodeVerifierCache(settings)
        }
        install(Postgrest)
    }
}

/** Why there's no access token. */
sealed class SessionException(message: String, cause: Throwable? = null) : IOException(message, cause) {
    /** Offline or the server didn't answer: keep everything, retry later. */
    class Transport(cause: Throwable? = null) : SessionException("transport", cause)
    /** No session could be made (e.g. anonymous sign-ins switched off). */
    class AuthFailed(cause: Throwable? = null) : SessionException("auth failed", cause)
}

/** The access token behind the stats uploads; the account and chat use the SDK directly. */
interface SessionProvider {
    /**
     * The current access token, refreshed when needed; `null` when the phone has no
     * session and [createAnonymous] is false. A phone gets an anonymous user only on
     * its first stats upload; signing in later upgrades that user (stats stay).
     */
    suspend fun accessToken(createAnonymous: Boolean): String?

    /** After a 401 from the REST API: refresh once and return the new token. */
    suspend fun refreshedAccessToken(): String

    /** After "Smazat moje statistiky": the server deleted an anonymous user, forget it here. */
    suspend fun forgetIfAnonymous()
}

/**
 * [SessionProvider] on top of supabase-kt. Before 1.3 the stats client kept its own
 * anonymous session in [legacyPrefs] (`supabase.session`); its refresh token is handed
 * to the SDK once, so the listener keeps the same user. Until that works (offline), no
 * new anonymous user is made, which would split the listener in two. As `SupabaseSession`
 * and `LegacySessionMigration` in AppSupabase.swift.
 */
class SupabaseSessionProvider(
    private val supabase: SupabaseClient,
    private val legacyPrefs: SharedPreferences,
) : SessionProvider {
    private val auth get() = supabase.auth
    private val mutex = Mutex()
    @Volatile private var migrated = false

    suspend fun migrateLegacySession() = mutex.withLock {
        if (migrated) return@withLock
        auth.awaitInitialization()
        val raw = legacyPrefs.getString(LEGACY_SESSION, null)
        val refreshToken = raw?.let {
            runCatching { Json.parseToJsonElement(it).jsonObject["refreshToken"]?.jsonPrimitive?.content }.getOrNull()
        }
        if (refreshToken != null && auth.currentSessionOrNull() == null) {
            try {
                auth.importSession(auth.refreshSession(refreshToken))
            } catch (e: Exception) {
                if (isTransport(e)) throw SessionException.Transport(e)
                // The old session is no longer valid: start fresh, like before.
            }
        }
        if (raw != null) legacyPrefs.edit().remove(LEGACY_SESSION).apply()
        migrated = true
    }

    override suspend fun accessToken(createAnonymous: Boolean): String? {
        migrateLegacySession()
        auth.currentSessionOrNull()?.let { session ->
            if (session.expiresAt - Clock.System.now() > 60.seconds) return session.accessToken
            try {
                auth.refreshCurrentSession()
                auth.currentAccessTokenOrNull()?.let { return it }
            } catch (e: Exception) {
                if (isTransport(e)) throw SessionException.Transport(e)
                // No longer accepted (signed out elsewhere, account deleted): forget it.
                auth.clearSession()
            }
        }
        if (!createAnonymous) return null
        return try {
            auth.signInAnonymously()
            auth.currentAccessTokenOrNull() ?: throw SessionException.AuthFailed()
        } catch (e: SessionException) {
            throw e
        } catch (e: Exception) {
            throw if (isTransport(e)) SessionException.Transport(e) else SessionException.AuthFailed(e)
        }
    }

    override suspend fun refreshedAccessToken(): String = try {
        auth.refreshCurrentSession()
        auth.currentAccessTokenOrNull() ?: throw SessionException.AuthFailed()
    } catch (e: SessionException) {
        throw e
    } catch (e: Exception) {
        throw if (isTransport(e)) SessionException.Transport(e) else SessionException.AuthFailed(e)
    }

    override suspend fun forgetIfAnonymous() {
        if (auth.currentUserOrNull()?.isAnonymous == true) auth.clearSession()
    }

    companion object {
        const val LEGACY_SESSION = "supabase.session"

        fun isTransport(e: Throwable): Boolean =
            e is HttpRequestException || e is HttpRequestTimeoutException ||
                (e is IOException && e !is SessionException.AuthFailed)
    }
}
