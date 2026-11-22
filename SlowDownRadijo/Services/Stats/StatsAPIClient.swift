import Foundation

/// One bucket of listening: seconds of playback on one of the listener's own
/// calendar days, attributed to the show that was airing at the time.
struct ListeningRow: Codable, Hashable {
    let day: String
    let showID: String
    var seconds: Int
    /// What really played (`mp3` / `aac`) and the sound-quality setting
    /// (`auto` / `high` / `low`), counted on the server only as totals
    /// (027). Missing in rows saved by an older version.
    var stream: String? = nil
    var quality: String? = nil

    enum CodingKeys: String, CodingKey {
        case day
        case showID = "show_id"
        case seconds
        case stream
        case quality
    }
}

/// Talks to Supabase for the listening stats — plain REST for the stats
/// functions; the session itself comes from the app's Supabase client
/// (`SupabaseSession`), shared with the account and the chat.
///
/// Identity is a Supabase *anonymous* auth user, created lazily on the first
/// upload (so installs that never really listen never create one). Signing
/// in (Profil) upgrades that very same user to a permanent account, so it
/// keeps all its stats.
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

    // MARK: - Public API

    func recordListening(batchID: UUID, rows: [ListeningRow], appVersion: String) async throws {
        #if DEBUG
        // UI tests and screenshot runs (`-statsDryRun YES`): a simulator in
        // CI isn't a listener, so nothing reaches the station's stats — and
        // with no upload, no anonymous account is created either. The batch
        // counts as sent, so the phone's own totals still add up.
        if UserDefaults.standard.bool(forKey: "statsDryRun") { return }
        #endif
        let body = try JSONEncoder().encode(RecordBody(batchID: batchID, rows: rows, appVersion: appVersion))
        _ = try await authenticatedRPC("record_listening", body: body, creatingAnonymous: true)
    }

    /// The raw `get_my_stats` JSON, or `nil` when this phone has no session
    /// yet — i.e. it never listened long enough to upload anything and never
    /// signed in. Opening the stats screen must not create an account.
    func fetchMyStats() async throws -> Data? {
        try await authenticatedRPC("get_my_stats", body: Data("{}".utf8), creatingAnonymous: false)
    }

    /// Public, session-less summary (`public_stats()`): whether the stats UI
    /// is unlocked yet, plus the community numbers. Zeros until it is.
    func fetchPublicStats() async throws -> Data {
        try await send(path: "rest/v1/rpc/public_stats", body: Data("{}".utf8), bearer: nil)
    }

    /// "Smazat moje statistiky" — removes the listener's rows server-side.
    /// For an anonymous listener the server deletes the user too, so the
    /// session is forgotten here and the next listen starts under a new id.
    /// A signed-in listener keeps their account (only the stats go).
    func deleteMyData() async throws {
        // No session means nothing was ever uploaded — nothing to delete,
        // and asking would create an anonymous account just to delete it.
        guard try await authenticatedRPC("delete_my_listening_data", body: Data("{}".utf8), creatingAnonymous: false) != nil else {
            return
        }
        if SupabaseSession.isAnonymous {
            try? await AppSupabase.client.auth.signOut(scope: .local)
        }
    }

    // MARK: - Requests

    /// `nil` when there is no session and `creatingAnonymous` is false.
    private func authenticatedRPC(_ name: String, body: Data, creatingAnonymous: Bool) async throws -> Data? {
        let path = "rest/v1/rpc/\(name)"
        let token: String
        do {
            guard let current = try await SupabaseSession.accessToken(creatingAnonymous: creatingAnonymous) else { return nil }
            token = current
        } catch {
            throw SupabaseSession.isTransport(error) ? APIError.transport : APIError.authFailed
        }
        do {
            return try await send(path: path, body: body, bearer: token)
        } catch APIError.server(401) {
            // Access token expired or revoked server-side: renew once, retry.
            let renewed: String
            do {
                renewed = try await SupabaseSession.refreshedAccessToken()
            } catch {
                throw SupabaseSession.isTransport(error) ? APIError.transport : APIError.authFailed
            }
            return try await send(path: path, body: body, bearer: renewed)
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
