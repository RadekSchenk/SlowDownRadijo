package cz.slowdownradijo.app.account

import cz.slowdownradijo.app.R

import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
import kotlinx.serialization.json.JsonPrimitive
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField

/**
 * What can go wrong with an account or a chat action: the stable codes that
 * `backend/supabase/sql/020_chat.sql` raises plus the sign-in failures. As
 * `AccountError.swift`; the texts live in `L10n`.
 */
sealed class AccountError(message: String) : Exception(message) {
    /** The text for a toast or an error line under a field (`userMessage` on iOS). */
    val messageRes: Int get() = when (this) {
        Offline -> R.string.errorOffline
        TooManyRequests, RateLimited -> R.string.errorTooManyRequests
        CodeInvalid -> R.string.emailCodeInvalid
        NicknameTaken -> R.string.nicknameTaken
        NicknameReserved -> R.string.nicknameReserved
        NicknameInvalid -> R.string.nicknameInvalid
        ProviderUnavailable -> R.string.signInUnavailable
        else -> R.string.errorGeneric
    }

    data object Offline : AccountError("offline")
    data object NotSignedIn : AccountError("not_authenticated")
    data object AccountRequired : AccountError("account_required")
    data object NicknameRequired : AccountError("nickname_required")
    data object NicknameInvalid : AccountError("nickname_invalid")
    data object NicknameReserved : AccountError("nickname_reserved")
    data object NicknameTaken : AccountError("nickname_taken")
    data class NicknameCooldown(val until: Instant?) : AccountError("nickname_cooldown")
    data object NicknameHost : AccountError("nickname_host")
    data object InviteInvalid : AccountError("invite_invalid")
    data object InviteOtherHost : AccountError("invite_other_host")
    data object MessageInvalid : AccountError("message_invalid")
    data object MessageNotFound : AccountError("message_not_found")
    data class Muted(val until: Instant?) : AccountError("muted")
    data object Blocked : AccountError("blocked")
    data object RateLimited : AccountError("rate_limited")
    data object NotModerator : AccountError("not_moderator")
    data object NotAdmin : AccountError("not_admin")
    data object UserInvalid : AccountError("user_invalid")
    data object MuteInvalid : AccountError("mute_invalid")
    data object RestoreExpired : AccountError("restore_expired")
    /** The e-mail code is wrong or expired. */
    data object CodeInvalid : AccountError("code_invalid")
    data object TooManyRequests : AccountError("too_many_requests")
    /** Google sign-in isn't configured in this build. */
    data object ProviderUnavailable : AccountError("provider_unavailable")
    /** The listener closed the sign-in sheet. */
    data object Cancelled : AccountError("cancelled")
    class Unknown(val detail: String) : AccountError(detail)

    companion object {
        fun from(e: Throwable): AccountError = when {
            e is AccountError -> e
            SupabaseSessionProvider.isTransport(e) && e !is SessionException.AuthFailed -> Offline
            e is SessionException.AuthFailed -> NotSignedIn
            e is PostgrestRestException -> fromServerCode(e.error, (e.details as? JsonPrimitive)?.content)
            e is AuthRestException -> when (e.errorCode) {
                AuthErrorCode.OtpExpired, AuthErrorCode.BadCodeVerifier -> CodeInvalid
                AuthErrorCode.OverEmailSendRateLimit, AuthErrorCode.OverRequestRateLimit -> TooManyRequests
                AuthErrorCode.SessionNotFound, AuthErrorCode.RefreshTokenNotFound -> NotSignedIn
                else -> Unknown(e.error)
            }
            else -> Unknown(e.message ?: e.toString())
        }

        fun fromServerCode(code: String, detail: String? = null): AccountError {
            val date = detail?.let(::parseDate)
            return when (code.lineSequence().first().trim()) {
                "not_authenticated" -> NotSignedIn
                "account_required" -> AccountRequired
                "nickname_required" -> NicknameRequired
                "nickname_invalid" -> NicknameInvalid
                "nickname_reserved" -> NicknameReserved
                "nickname_taken" -> NicknameTaken
                "nickname_cooldown" -> NicknameCooldown(date)
                "nickname_host" -> NicknameHost
                "invite_invalid" -> InviteInvalid
                "invite_other_host" -> InviteOtherHost
                "message_invalid" -> MessageInvalid
                "message_not_found" -> MessageNotFound
                "muted" -> Muted(date)
                "blocked" -> Blocked
                "rate_limited" -> RateLimited
                "not_moderator" -> NotModerator
                "not_admin" -> NotAdmin
                "user_invalid" -> UserInvalid
                "mute_invalid" -> MuteInvalid
                "restore_expired" -> RestoreExpired
                else -> Unknown(code)
            }
        }

        /** Postgres `timestamptz::text`, e.g. `2026-11-18 08:04:12.345678+00`. */
        fun parseDate(text: String): Instant? {
            if (text.isBlank()) return null
            val postgres = DateTimeFormatterBuilder()
                .appendPattern("yyyy-MM-dd HH:mm:ss")
                .optionalStart().appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true).optionalEnd()
                .appendPattern("X")
                .toFormatter()
            return runCatching { OffsetDateTime.parse(text, postgres).toInstant() }.getOrNull()
                ?: runCatching { OffsetDateTime.parse(text).toInstant() }.getOrNull()
        }
    }
}
