import Foundation

/// A single row from the `social_stats` table — cached follower/like
/// counts for the station's social links, refreshed periodically by the
/// `update-social-stats` Edge Function rather than fetched live per app
/// open (see `backend/supabase/sql/005_social_stats.sql`). Read directly
/// via Supabase's REST API (PostgREST), same pattern as `RemotePlayedTrack`.
struct SocialStat: Decodable {
    /// Matches `SocialLinksRow`'s platform ids: "youtube", "instagram",
    /// "facebook", "threads".
    let platform: String
    let followerCount: Int

    enum CodingKeys: String, CodingKey {
        case platform
        case followerCount = "follower_count"
    }
}
