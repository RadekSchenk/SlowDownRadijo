import Foundation

/// Reads `social_stats` directly from Supabase's REST API (PostgREST). The
/// table has a public read RLS policy (see
/// `backend/supabase/sql/005_social_stats.sql`), so this only needs the
/// anon key, not a service-role secret — same pattern as
/// `RemoteHistoryService`.
enum SocialStatsService {
    private static let baseURL = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/rest/v1/social_stats")!
    private static let anonKey = "sb_publishable_KjKHzi03xlmnhNAnxD87oQ_6p-Qb1Su"

    static func fetchAll() async throws -> [SocialStat] {
        var request = URLRequest(url: baseURL)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SocialStat].self, from: data)
    }
}
