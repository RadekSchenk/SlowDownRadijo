import Foundation

/// Fetches radio-wide stats from the `get-stats` Edge Function — see
/// `backend/supabase/functions/get-stats`. Read-only, no auth needed.
enum StatisticsService {
    static let endpoint = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/functions/v1/get-stats")!

    static func fetch() async throws -> StatsResponse {
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(StatsResponse.self, from: data)
    }
}
