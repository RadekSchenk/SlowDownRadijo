import Foundation
import Supabase

/// What can go wrong with an account or a chat action, by the stable codes
/// that `backend/supabase/sql/020_chat.sql` raises (`chat_error(...)`) plus
/// the sign-in failures. The texts live in `L10n`.
enum AccountError: Error, Equatable {
    case offline
    case notSignedIn
    case accountRequired
    case nicknameRequired
    case nicknameInvalid
    case nicknameReserved
    case nicknameTaken
    /// The nickname can change again at this moment.
    case nicknameCooldown(until: Date?)
    case nicknameHost
    case inviteInvalid
    case inviteOtherHost
    case messageInvalid
    case messageNotFound
    case muted(until: Date?)
    case blocked
    case rateLimited
    case notModerator
    case notAdmin
    case notSuperadmin
    case hostInvalid
    case userInvalid
    case muteInvalid
    case restoreExpired
    /// The e-mail code is wrong or expired.
    case codeInvalid
    /// Too many codes asked for in a short time.
    case tooManyRequests
    /// Google sign-in isn't configured in this build.
    case providerUnavailable
    /// The listener closed Apple's or Google's sheet.
    case cancelled
    case unknown(String)

    /// Turns an SDK, PostgREST or network error into an `AccountError`.
    static func from(_ error: Error) -> AccountError {
        if let account = error as? AccountError { return account }
        if SupabaseSession.isTransport(error) { return .offline }
        if let failure = error as? SupabaseSession.Failure, case .authFailed = failure { return .notSignedIn }

        if let postgrest = error as? PostgrestError {
            return fromServerCode(postgrest.message, detail: postgrest.details)
        }
        if let auth = error as? AuthError {
            switch auth.errorCode {
            case .otpExpired, .badCodeVerifier:
                return .codeInvalid
            case .overEmailSendRateLimit, .overRequestRateLimit:
                return .tooManyRequests
            case .sessionNotFound, .refreshTokenNotFound:
                return .notSignedIn
            default:
                if case .sessionMissing = auth { return .notSignedIn }
                return .unknown(auth.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }

    static func fromServerCode(_ code: String, detail: String? = nil) -> AccountError {
        let date = detail.flatMap(Self.parseDate)
        switch code {
        case "not_authenticated": return .notSignedIn
        case "account_required": return .accountRequired
        case "nickname_required": return .nicknameRequired
        case "nickname_invalid": return .nicknameInvalid
        case "nickname_reserved": return .nicknameReserved
        case "nickname_taken": return .nicknameTaken
        case "nickname_cooldown": return .nicknameCooldown(until: date)
        case "nickname_host": return .nicknameHost
        case "invite_invalid": return .inviteInvalid
        case "invite_other_host": return .inviteOtherHost
        case "message_invalid": return .messageInvalid
        case "message_not_found": return .messageNotFound
        case "muted": return .muted(until: date)
        case "blocked": return .blocked
        case "rate_limited": return .rateLimited
        case "not_moderator": return .notModerator
        case "not_admin": return .notAdmin
        case "not_superadmin": return .notSuperadmin
        case "host_invalid": return .hostInvalid
        case "user_invalid": return .userInvalid
        case "mute_invalid": return .muteInvalid
        case "restore_expired": return .restoreExpired
        default: return .unknown(code)
        }
    }

    /// Postgres `timestamptz::text`, e.g. `2026-11-18 08:04:12.345678+00`.
    static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss.SSSSSSXXX", "yyyy-MM-dd HH:mm:ssXXX", "yyyy-MM-dd HH:mm:ss.SSSSSSX", "yyyy-MM-dd HH:mm:ssX"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }
}

extension AccountError {
    /// A short text for a toast or an error line under a field.
    var userMessage: String {
        switch self {
        case .offline: return L10n.errorOffline
        case .tooManyRequests, .rateLimited: return L10n.errorTooManyRequests
        case .codeInvalid: return L10n.emailCodeInvalid
        case .nicknameTaken: return L10n.nicknameTaken
        case .nicknameReserved: return L10n.nicknameReserved
        case .nicknameInvalid: return L10n.nicknameInvalid
        case .providerUnavailable: return L10n.signInUnavailable
        case .inviteOtherHost: return L10n.errorInviteOtherHost
        case .inviteInvalid: return L10n.inviteInvalidBody
        case .restoreExpired: return L10n.errorRestoreExpired
        case .notModerator, .notAdmin: return L10n.errorNotModerator
        case .notSuperadmin: return L10n.errorNotSuperadmin
        case .hostInvalid: return L10n.errorHostInvalid
        case .userInvalid: return L10n.errorUserInvalid
        case .messageNotFound: return L10n.errorMessageNotFound
        case .muted: return L10n.errorMuted
        case .blocked: return L10n.blockedBanner
        default: return L10n.errorGeneric
        }
    }
}
