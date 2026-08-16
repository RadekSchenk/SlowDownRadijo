import Foundation

/// Fetches just the single most recent row from `played_tracks` — a
/// trimmed-down sibling of `RemoteHistoryService.fetchPage` sized for the
/// widget's own independent timeline refresh (no pagination needed here,
/// and no shared App Group with the host app — the widget process fetches
/// this itself on each refresh).
enum LatestTrackService {
    private static let baseURL = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/rest/v1/played_tracks")!
    /// Same public "anon" key the app embeds in `RemoteHistoryService` —
    /// safe to duplicate here, it only grants what the table's RLS policy
    /// already allows (public read, no writes).
    private static let anonKey = "sb_publishable_KjKHzi03xlmnhNAnxD87oQ_6p-Qb1Su"

    static func fetchLatest() async -> RemotePlayedTrack? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,artist,title,played_at,show_name"),
            URLQueryItem(name: "order", value: "played_at.desc"),
            URLQueryItem(name: "limit", value: "1"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let tracks = try? JSONDecoder().decode([RemotePlayedTrack].self, from: data) else {
            return nil
        }
        return tracks.first
    }
}
