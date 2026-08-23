import Foundation

/// Reads `played_tracks` directly from Supabase's REST API (PostgREST). The
/// table has a public read RLS policy (see
/// `backend/supabase/sql/001_played_tracks.sql`), so this only needs the
/// anon key, not a service-role secret.
enum RemoteHistoryService {
    private static let baseURL = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/rest/v1/played_tracks")!
    /// Supabase's "anon" public key — safe to embed, it only grants what
    /// the table's RLS policy already allows (public read, no writes).
    private static let anonKey = "sb_publishable_KjKHzi03xlmnhNAnxD87oQ_6p-Qb1Su"

    /// Fetches up to `limit` rows strictly older than `cursor` (or from the
    /// very top if `cursor` is `nil`), no older than `windowStart`, newest
    /// first — mirrors `PlayHistoryStore.fetchPage`'s cursor shape so
    /// `HistoryViewModel` can page through both sources the same way.
    /// PostgREST ANDs repeated query params on the same column, so passing
    /// `played_at` twice (once for each bound) works as a single filter.
    static func fetchPage(before cursor: Date?, windowStart: Date, limit: Int) async throws -> [RemotePlayedTrack] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "select", value: "id,artist,title,played_at,show_name"),
            URLQueryItem(name: "played_at", value: "gte.\(ISO8601DateFormatter().string(from: windowStart))"),
            URLQueryItem(name: "order", value: "played_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "played_at", value: "lt.\(ISO8601DateFormatter().string(from: cursor))"))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([RemotePlayedTrack].self, from: data)
    }
}
