import Foundation
import Supabase

/// The app's one Supabase client: accounts (Apple, Google, e-mail code),
/// the chat and — through `SupabaseSession` — the listening stats.
///
/// The session lives in the Keychain (`KeychainAuthStorage`), like the
/// anonymous stats session did before 1.3, so it survives reinstalling the
/// app and is readable in the background while the phone is locked.
enum AppSupabase {
    static let client = SupabaseClient(
        supabaseURL: StatsConfig.baseURL,
        supabaseKey: StatsConfig.publishableKey,
        options: SupabaseClientOptions(
            auth: .init(
                storage: KeychainAuthStorage(),
                redirectToURL: URL(string: "slowdownradijo://auth"),
                flowType: .pkce,
                autoRefreshToken: true,
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}

/// `AuthLocalStorage` on top of `KeychainStore` (`AfterFirstUnlockThisDeviceOnly`).
struct KeychainAuthStorage: AuthLocalStorage {
    private static let prefix = "auth."

    func store(key: String, value: Data) throws {
        KeychainStore.write(value, account: Self.prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        KeychainStore.read(account: Self.prefix + key)
    }

    func remove(key: String) throws {
        KeychainStore.delete(account: Self.prefix + key)
    }
}

/// The access token behind every authenticated call, for the stats client
/// (plain REST) and the account and chat services (SDK).
///
/// Identity rules, the same as before 1.3:
///   * A phone gets an *anonymous* user only when it first uploads listening
///     stats (`creatingAnonymous: true`); reading never creates one.
///   * Signing in (Apple, Google, e-mail) upgrades that anonymous user to a
///     permanent account, so the stats carry over — see `AccountService`.
enum SupabaseSession {
    enum Failure: Error {
        /// Offline or the server didn't answer — keep everything, retry later.
        case transport
        /// No session could be made (e.g. anonymous sign-ins switched off).
        case authFailed
    }

    /// The current access token, refreshed when needed; `nil` when the phone
    /// has no session and `creatingAnonymous` is false.
    static func accessToken(creatingAnonymous: Bool) async throws -> String? {
        try await LegacySessionMigration.shared.runIfNeeded()
        let auth = AppSupabase.client.auth

        if auth.currentSession != nil {
            do {
                return try await auth.session.accessToken
            } catch {
                if isTransport(error) { throw Failure.transport }
                // The server no longer accepts this session (signed out
                // elsewhere, account deleted): forget it.
                try? await auth.signOut(scope: .local)
            }
        }

        guard creatingAnonymous else { return nil }
        do {
            return try await auth.signInAnonymously().accessToken
        } catch {
            throw isTransport(error) ? Failure.transport : Failure.authFailed
        }
    }

    /// After a 401 from the REST API: refresh once and hand back the new token.
    static func refreshedAccessToken() async throws -> String {
        do {
            return try await AppSupabase.client.auth.refreshSession().accessToken
        } catch {
            throw isTransport(error) ? Failure.transport : Failure.authFailed
        }
    }

    static var hasSession: Bool {
        AppSupabase.client.auth.currentSession != nil
    }

    static var isAnonymous: Bool {
        AppSupabase.client.auth.currentUser?.isAnonymous ?? false
    }

    static func isTransport(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let failure = error as? Failure, case .transport = failure { return true }
        return false
    }
}

/// Before 1.3 the stats client kept its own anonymous session in the
/// Keychain (`supabase.session`). On the first launch of 1.3 its refresh
/// token is handed to the SDK, so the listener keeps the same user and
/// their stats. Until that succeeds (offline), no new anonymous user is
/// made — that would split the listener in two.
actor LegacySessionMigration {
    static let shared = LegacySessionMigration()

    private static let legacyAccount = "supabase.session"
    private var done = false

    private struct LegacySession: Decodable {
        let refreshToken: String
    }

    func runIfNeeded() async throws {
        guard !done else { return }
        guard let data = KeychainStore.read(account: Self.legacyAccount) else {
            done = true
            return
        }
        let auth = AppSupabase.client.auth
        guard auth.currentSession == nil,
              let legacy = try? JSONDecoder().decode(LegacySession.self, from: data) else {
            KeychainStore.delete(account: Self.legacyAccount)
            done = true
            return
        }
        do {
            _ = try await auth.refreshSession(refreshToken: legacy.refreshToken)
        } catch {
            if SupabaseSession.isTransport(error) {
                throw SupabaseSession.Failure.transport
            }
            // The old session is no longer valid: start fresh like before.
        }
        KeychainStore.delete(account: Self.legacyAccount)
        done = true
    }
}
