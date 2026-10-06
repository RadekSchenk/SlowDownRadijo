import Foundation

/// One bucket of listening: seconds of playback on one of the listener's own
/// calendar days, attributed to the show that was airing at the time.
struct ListeningRow: Codable, Hashable {
    let day: String
    let showID: String
    var seconds: Int

    enum CodingKeys: String, CodingKey {
        case day
        case showID = "show_id"
        case seconds
    }
}

/// Talks to Supabase for the listening stats — plain REST, no SDK, like the
/// app's other services.
///
/// Identity is a Supabase *anonymous* auth user, created lazily on the first
/// upload (so installs that never really listen never create one). Its
/// session lives in the Keychain; when registration arrives, the very same
/// user is upgraded to a permanent account and keeps all its stats.
actor StatsAPIClient {
    static let shared = StatsAPIClient()

    enum APIError: Error {
        /// Offline, timed out, … — try again later.
        case transport
        /// Server-side or configuration trouble (5xx, 429, function not
        /// deployed yet, permissions) — the data is fine, try again later.
        case server(Int)
        /// The server judged this particular payload invalid (400/422).
        /// Retrying the same batch can never succeed.
        case rejected(Int)
        /// Couldn't obtain an anonymous session (e.g. anonymous sign-ins
        /// not enabled in Supabase yet) — keep the data, try again later.
        case authFailed
    }

    private struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }

    private struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
    }

    private struct RecordBody: Encodable {
        let batchID: UUID
        let rows: [ListeningRow]
        let appVersion: String

        enum CodingKeys: String, CodingKey {
            case batchID = "p_batch_id"
            case rows = "p_rows"
            case appVersion = "p_app_version"
        }
    }

    private static let sessionAccount = "supabase.session"

    private var session: Session?
    private var didLoadStoredSession = false

    // MARK: - Public API

    func recordListening(batchID: UUID, rows: [ListeningRow], appVersion: String) async throws {
        let body = try JSONEncoder().encode(RecordBody(batchID: batchID, rows: rows, appVersion: appVersion))
        _ = try await authenticatedRPC("record_listening", body: body)
    }

    /// The raw `get_my_stats` JSON, or `nil` when this phone has no
    /// anonymous session yet — i.e. it never listened long enough to upload
    /// anything. Opening the stats screen must not create an account.
    func fetchMyStats() async throws -> Data? {
        loadStoredSessionIfNeeded()
        guard session != nil else { return nil }
        return try await authenticatedRPC("get_my_stats", body: Data("{}".utf8))
    }

    /// Public, session-less summary (`public_stats()`): whether the stats UI
    /// is unlocked yet, plus the community numbers. Zeros until it is.
    func fetchPublicStats() async throws -> Data {
        try await send(path: "rest/v1/rpc/public_stats", body: Data("{}".utf8), bearer: nil)
    }

    /// "Smazat moje statistiky" — removes the listener's rows server-side.
    func deleteMyData() async throws {
        _ = try await authenticatedRPC("delete_my_listening_data", body: Data("{}".utf8))
    }

    // MARK: - Session

    private func loadStoredSessionIfNeeded() {
        guard !didLoadStoredSession else { return }
        didLoadStoredSession = true
        if let data = KeychainStore.read(account: Self.sessionAccount) {
            session = try? JSONDecoder().decode(Session.self, from: data)
        }
    }

    private func currentSession() async throws -> Session {
        loadStoredSessionIfNeeded()
        if let session, session.expiresAt.timeIntervalSinceNow > 60 {
            return session
        }
        return try await renewSession()
    }

    /// Refreshes the stored session; only if the server no longer accepts
    /// its refresh token (not on a mere network error) does it fall back to a
    /// brand-new anonymous user.
    private func renewSession() async throws -> Session {
        if let stored = session {
            do {
                let body = try JSONEncoder().encode(["refresh_token": stored.refreshToken])
                let data = try await send(
                    path: "auth/v1/token",
                    query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                    body: body,
                    bearer: nil
                )
                return try store(authResponse: data)
            } catch APIError.rejected(_) {
                // Refresh token no longer valid — fall through to a new anonymous user.
            }
            // Network or 5xx trouble propagates: keep the identity, retry later.
        }
        do {
            return try store(authResponse: try await send(path: "auth/v1/signup", body: Data("{}".utf8), bearer: nil))
        } catch APIError.transport {
            throw APIError.transport
        } catch {
            throw APIError.authFailed
        }
    }

    private func store(authResponse data: Data) throws -> Session {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(AuthResponse.self, from: data) else {
            throw APIError.authFailed
        }
        let newSession = Session(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        session = newSession
        if let encoded = try? JSONEncoder().encode(newSession) {
            KeychainStore.write(encoded, account: Self.sessionAccount)
        }
        return newSession
    }

    // MARK: - Requests

    private func authenticatedRPC(_ name: String, body: Data) async throws -> Data {
        let path = "rest/v1/rpc/\(name)"
        let current = try await currentSession()
        do {
            return try await send(path: path, body: body, bearer: current.accessToken)
        } catch APIError.server(401) {
            // Access token expired or revoked server-side: renew once, retry.
            let renewed = try await renewSession()
            return try await send(path: path, body: body, bearer: renewed.accessToken)
        }
    }

    private func send(path: String, query: [URLQueryItem] = [], body: Data, bearer: String?) async throws -> Data {
        var components = URLComponents(url: StatsConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(StatsConfig.publishableKey, forHTTPHeaderField: "apikey")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport }

        switch http.statusCode {
        case 200..<300:
            return data
        case 400, 422:
            throw APIError.rejected(http.statusCode)
        default:
            throw APIError.server(http.statusCode)
        }
    }
}
