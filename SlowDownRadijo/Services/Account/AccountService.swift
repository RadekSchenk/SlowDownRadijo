import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import Supabase
import UIKit

/// The listener's account: signing in with Apple, Google or an e-mail code,
/// the nickname, the DJ link, signing out and deleting the account.
///
/// Signing in on a phone that already has an anonymous stats user *links*
/// the new sign-in to that user, so the listening stats stay. Only when the
/// e-mail / Apple ID / Google account already belongs to another account
/// (the listener signs in on a second phone) does the phone switch to that
/// account; the anonymous user is then left to the 24-month clean-up.
///
/// Mirrors `android/.../account/AccountService.kt`.
@MainActor
final class AccountService: ObservableObject {
    static let shared = AccountService()

    /// What `chat_me()` returns (backend/supabase/sql/020_chat.sql, 022_chat_v3.sql).
    struct Me: Decodable, Equatable {
        enum Role: String, Decodable { case listener, supporter, dj, admin }

        var userID: UUID
        var isAnonymous = false
        /// When the listener became a Slowrider ("Jsi součástí Slowriders od …").
        var registeredAt: Date?
        var nickname: String?
        /// Anonymous with a nickname: changing it needs registration.
        var nicknameLocked = false
        var nicknameNextChangeAt: Date?
        var role: Role = .listener
        var hostID: String?
        var hostName: String?
        var isModerator = false
        var isAdmin = false
        var isSuperadmin = false
        var chatMessagesCount = 0
        var voiceMessagesCount = 0
        var mutedUntil: Date?
        var blocked = false

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case isAnonymous = "is_anonymous"
            case registeredAt = "registered_at"
            case nickname
            case nicknameLocked = "nickname_locked"
            case nicknameNextChangeAt = "nickname_next_change_at"
            case role
            case hostID = "host_id"
            case hostName = "host_name"
            case isModerator = "is_moderator"
            case isAdmin = "is_admin"
            case isSuperadmin = "is_superadmin"
            case chatMessagesCount = "chat_messages_count"
            case voiceMessagesCount = "voice_messages_count"
            case mutedUntil = "muted_until"
            case blocked
        }

        init(userID: UUID, nickname: String? = nil) {
            self.userID = userID
            self.nickname = nickname
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            userID = try c.decode(UUID.self, forKey: .userID)
            func date(_ key: CodingKeys) -> Date? {
                (try? c.decodeIfPresent(String.self, forKey: key)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
            }
            isAnonymous = (try? c.decodeIfPresent(Bool.self, forKey: .isAnonymous)) ?? false
            registeredAt = date(.registeredAt)
            nickname = try? c.decodeIfPresent(String.self, forKey: .nickname)
            nicknameLocked = (try? c.decodeIfPresent(Bool.self, forKey: .nicknameLocked)) ?? false
            nicknameNextChangeAt = date(.nicknameNextChangeAt)
            role = (try? c.decodeIfPresent(Role.self, forKey: .role)) ?? .listener
            hostID = try? c.decodeIfPresent(String.self, forKey: .hostID)
            hostName = try? c.decodeIfPresent(String.self, forKey: .hostName)
            isModerator = (try? c.decodeIfPresent(Bool.self, forKey: .isModerator)) ?? false
            isAdmin = (try? c.decodeIfPresent(Bool.self, forKey: .isAdmin)) ?? false
            isSuperadmin = (try? c.decodeIfPresent(Bool.self, forKey: .isSuperadmin)) ?? false
            chatMessagesCount = (try? c.decodeIfPresent(Int.self, forKey: .chatMessagesCount)) ?? 0
            voiceMessagesCount = (try? c.decodeIfPresent(Int.self, forKey: .voiceMessagesCount)) ?? 0
            mutedUntil = date(.mutedUntil)
            blocked = (try? c.decodeIfPresent(Bool.self, forKey: .blocked)) ?? false
        }

        /// The name the listener writes under: the DJ name or the nickname.
        var chatName: String? { hostName ?? nickname }
        var isHost: Bool { hostID != nil }
    }

    enum SignInMethod: String, Equatable {
        case apple, google, email
    }

    enum State: Equatable {
        /// Not known yet (first moments after launch).
        case loading
        /// No permanent account and no nickname yet (maybe an anonymous
        /// stats user).
        case signedOut
        /// Writes in the chat without an account: the phone's anonymous user
        /// with a nickname (Figma Profil M7). Registering keeps everything.
        case anonymous(me: Me)
        /// Signed in; `me` is nil until `chat_me()` answered (offline).
        case signedIn(method: SignInMethod?, email: String?, me: Me?)
    }

    /// Where an e-mail code was sent and what it will do.
    struct EmailCodeRequest: Equatable {
        let email: String
        /// `true`: it adds the e-mail to this phone's anonymous user
        /// (stats stay); `false`: it signs in to an existing account.
        let linksAnonymousUser: Bool
    }

    enum NicknameCheck: Equatable {
        case ok, invalid, reserved, taken
    }

    /// Someone this listener hid from their chat (`my_hidden_chat_users`).
    struct HiddenUser: Decodable, Identifiable, Equatable {
        let userID: UUID
        let name: String?
        var id: UUID { userID }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case name
        }
    }

    @Published private(set) var state: State = .loading
    /// Where the listener started registering, for `account_registered`.
    var registrationSource = "profile_empty"

    private var client: SupabaseClient { AppSupabase.client }
    private var observeTask: Task<Void, Never>?

    private init() {}

    /// Starts following the session; call once at launch.
    func start() {
        guard observeTask == nil else { return }
        #if DEBUG
        // Store screenshots: the sample Slowrider stays signed in.
        if StoreDemo.isOn { return }
        #endif
        observeTask = Task { [weak self] in
            try? await LegacySessionMigration.shared.runIfNeeded()
            guard let self else { return }
            for await (event, _) in self.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .signedOut, .userUpdated, .userDeleted:
                    await self.refresh()
                default:
                    break
                }
            }
        }
    }

    /// The listener in the chat: registered or writing without an account.
    var me: Me? {
        switch state {
        case .signedIn(_, _, let me): return me
        case .anonymous(let me): return me
        default: return nil
        }
    }

    /// A registered Slowrider (not just an anonymous writer).
    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Writing without an account, with a nickname.
    var isAnonymousWriter: Bool {
        if case .anonymous = state { return true }
        return false
    }

    /// The listener has a name to write under (registered or not).
    var canWriteInChat: Bool { me?.chatName != nil }

    /// For analytics: `none`, `anonymous`, `registered`.
    var analyticsAccount: String {
        switch state {
        case .signedIn: return "registered"
        case .anonymous: return "anonymous"
        default: return "none"
        }
    }

    #if DEBUG
    /// Store screenshots: a signed-in Slowrider without a session.
    func applyDemo(me: Me) {
        state = .signedIn(method: .apple, email: nil, me: me)
    }
    #endif

    /// Re-reads the account (after sign-in, a nickname change, a mute, …).
    func refresh() async {
        #if DEBUG
        if StoreDemo.isOn { return }
        #endif
        guard let user = client.auth.currentUser else {
            state = .signedOut
            return
        }
        if user.isAnonymous {
            // Writing without an account: the anonymous user with a nickname.
            do {
                let me: Me = try await client.rpc("chat_me").execute().value
                state = me.nickname == nil ? .signedOut : .anonymous(me: me)
            } catch {
                if case .anonymous = state { return } // offline: keep it
                state = .signedOut
            }
            return
        }
        let method = Self.signInMethod(of: user)
        let wasRegistered = isSignedIn
        let hadNickname = me?.nickname != nil
        do {
            let me: Me = try await client.rpc("chat_me").execute().value
            state = .signedIn(method: method, email: user.email, me: me)
            if !wasRegistered, let since = me.registeredAt, Date().timeIntervalSince(since) < 600 {
                // Just registered (Figma Profil M9).
                ToastCenter.shared.show(.init(
                    systemImage: "sparkles",
                    message: hadNickname || me.nickname != nil ? L10n.welcomeSlowriderNickname : L10n.welcomeSlowrider
                ))
                Analytics.shared.track(.accountRegistered(method: method?.rawValue ?? "unknown", source: registrationSource, hadNickname: hadNickname))
            } else if !wasRegistered {
                Analytics.shared.track(.accountSignedIn(method: method?.rawValue ?? "unknown", source: registrationSource))
            }
            registrationSource = "profile_empty"
        } catch {
            // Offline: keep what we knew about this account.
            if case .signedIn(_, _, let old) = state {
                state = .signedIn(method: method, email: user.email, me: old)
            } else {
                state = .signedIn(method: method, email: user.email, me: nil)
            }
        }
    }

    // MARK: - E-mail code

    /// Sends a 6-digit code. Returns what the code will do.
    func sendEmailCode(to rawEmail: String) async throws -> EmailCodeRequest {
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            try await LegacySessionMigration.shared.runIfNeeded()
            if let user = client.auth.currentUser, user.isAnonymous {
                do {
                    _ = try await client.auth.update(user: UserAttributes(email: email))
                    return EmailCodeRequest(email: email, linksAnonymousUser: true)
                } catch let error as AuthError where error.errorCode == .emailExists {
                    // Belongs to an existing account: sign in to it below.
                }
            }
            try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
            return EmailCodeRequest(email: email, linksAnonymousUser: false)
        } catch {
            throw AccountError.from(error)
        }
    }

    func verifyEmailCode(_ code: String, for request: EmailCodeRequest) async throws {
        let token = code.filter(\.isNumber)
        do {
            if request.linksAnonymousUser {
                try await client.auth.verifyOTP(email: request.email, token: token, type: .emailChange)
            } else {
                try await client.auth.verifyOTP(email: request.email, token: token, type: .email)
            }
        } catch let error as AuthError {
            if case .api(_, _, _, let response) = error, (400..<500).contains(response.statusCode),
               error.errorCode != .overRequestRateLimit {
                throw AccountError.codeInvalid
            }
            throw AccountError.from(error)
        } catch {
            throw AccountError.from(error)
        }
        await refresh()
    }

    // MARK: - Apple

    /// A fresh nonce for `SignInWithAppleButton`: put `hashed` into the
    /// request, give `raw` back to `signInWithApple`.
    static func makeAppleNonce() -> (raw: String, hashed: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let hashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }

    func signInWithApple(_ result: Result<ASAuthorization, Error>, rawNonce: String) async throws {
        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { throw AccountError.cancelled }
            throw AccountError.from(error)
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AccountError.unknown("apple_no_token")
        }
        try await signIn(with: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce))
    }

    // MARK: - Google

    /// The iOS OAuth client from Google Cloud (Info.plist `GIDClientID`,
    /// from the `GOOGLE_IOS_CLIENT_ID` build setting). Empty until set up.
    static var isGoogleConfigured: Bool {
        let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        return id.hasSuffix(".apps.googleusercontent.com")
    }

    func signInWithGoogle() async throws {
        guard Self.isGoogleConfigured else { throw AccountError.providerUnavailable }
        guard let presenter = Self.topViewController() else { throw AccountError.unknown("no_presenter") }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue { throw AccountError.cancelled }
            throw AccountError.from(error)
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw AccountError.unknown("google_no_token")
        }
        try await signIn(with: OpenIDConnectCredentials(
            provider: .google,
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        ))
    }

    /// Google's sign-in returns through the app's URL scheme.
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Shared sign-in

    private func signIn(with credentials: OpenIDConnectCredentials) async throws {
        do {
            try await LegacySessionMigration.shared.runIfNeeded()
            if let user = client.auth.currentUser, user.isAnonymous {
                do {
                    try await client.auth.linkIdentityWithIdToken(credentials: credentials)
                } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
                    try await client.auth.signInWithIdToken(credentials: credentials)
                }
            } else {
                try await client.auth.signInWithIdToken(credentials: credentials)
            }
        } catch {
            throw AccountError.from(error)
        }
        await refresh()
    }

    // MARK: - Nickname, DJ, account

    /// Sets the first nickname (also without an account: the phone's
    /// anonymous user is made if there's none yet) or changes it.
    func setNickname(_ nickname: String) async throws {
        do {
            _ = try await SupabaseSession.accessToken(creatingAnonymous: true)
            let me: Me = try await client.rpc("set_nickname", params: ["p_nickname": nickname]).execute().value
            switch state {
            case .signedIn(let method, let email, _):
                state = .signedIn(method: method, email: email, me: me)
            default:
                state = me.isAnonymous ? .anonymous(me: me) : state
                if !me.isAnonymous { await refresh() }
            }
        } catch {
            throw AccountError.from(error)
        }
    }

    /// The live check under the nickname field.
    func checkNickname(_ nickname: String) async throws -> NicknameCheck {
        do {
            let answer: String = try await client.rpc("nickname_available", params: ["p_nickname": nickname]).execute().value
            switch answer {
            case "ok": return .ok
            case "nickname_reserved": return .reserved
            case "nickname_taken": return .taken
            default: return .invalid
            }
        } catch {
            throw AccountError.from(error)
        }
    }

    func hiddenUsers() async throws -> [HiddenUser] {
        do {
            return try await client.rpc("my_hidden_chat_users").execute().value
        } catch {
            throw AccountError.from(error)
        }
    }

    func unhide(_ userID: UUID) async throws {
        do {
            try await client.rpc("unhide_chat_user", params: ["p_user": userID.uuidString]).execute()
        } catch {
            throw AccountError.from(error)
        }
    }

    /// A DJ opened their invite link (`https://slowdownradijo.cz/dj/<code>`).
    func claimHostInvite(_ code: String) async throws {
        do {
            let me: Me = try await client.rpc("claim_host_invite", params: ["p_code": code]).execute().value
            if case .signedIn(let method, let email, _) = state {
                state = .signedIn(method: method, email: email, me: me)
            }
        } catch {
            throw AccountError.from(error)
        }
    }

    /// "Hlasové vzkazy" on the Profil dashboard: counts a sent voice message
    /// for the listener, if the phone has an account (registered or not).
    func countVoiceMessage() async {
        guard (try? await SupabaseSession.accessToken(creatingAnonymous: false)) != nil else { return }
        _ = try? await client.rpc("count_voice_message").execute()
    }

    /// Signs out on this phone. Listening stats start again under a new
    /// anonymous user on the next upload.
    func signOut() async {
        try? await client.auth.signOut(scope: .local)
        try? await GIDSignIn.sharedInstance.signOut()
        state = .signedOut
    }

    /// Deletes the account and everything with it; chat messages stay as
    /// "Smazaný účet".
    func deleteAccount() async throws {
        do {
            try await client.rpc("delete_my_account").execute()
        } catch {
            throw AccountError.from(error)
        }
        await signOut()
    }

    // MARK: - Helpers

    private static func signInMethod(of user: User) -> SignInMethod? {
        let providers = (user.identities ?? []).map(\.provider)
        if providers.contains("apple") { return .apple }
        if providers.contains("google") { return .google }
        if providers.contains("email") || user.email != nil { return .email }
        return nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
