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

    /// What `chat_me()` returns (backend/supabase/sql/020_chat.sql).
    struct Me: Decodable, Equatable {
        enum Role: String, Decodable { case listener, supporter, dj, admin }

        let userID: UUID
        let nickname: String?
        let nicknameNextChangeAt: Date?
        let role: Role
        let hostID: String?
        let hostName: String?
        let isModerator: Bool
        let mutedUntil: Date?
        let blocked: Bool

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case nickname
            case nicknameNextChangeAt = "nickname_next_change_at"
            case role
            case hostID = "host_id"
            case hostName = "host_name"
            case isModerator = "is_moderator"
            case mutedUntil = "muted_until"
            case blocked
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
        /// No permanent account (maybe an anonymous stats user).
        case signedOut
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

    private var client: SupabaseClient { AppSupabase.client }
    private var observeTask: Task<Void, Never>?

    private init() {}

    /// Starts following the session; call once at launch.
    func start() {
        guard observeTask == nil else { return }
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

    var me: Me? {
        if case .signedIn(_, _, let me) = state { return me }
        return nil
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Re-reads the account (after sign-in, a nickname change, a mute, …).
    func refresh() async {
        guard let user = client.auth.currentUser, !user.isAnonymous else {
            state = .signedOut
            return
        }
        let method = Self.signInMethod(of: user)
        do {
            let me: Me = try await client.rpc("chat_me").execute().value
            state = .signedIn(method: method, email: user.email, me: me)
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

    func setNickname(_ nickname: String) async throws {
        do {
            let me: Me = try await client.rpc("set_nickname", params: ["p_nickname": nickname]).execute().value
            if case .signedIn(let method, let email, _) = state {
                state = .signedIn(method: method, email: email, me: me)
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
