import Foundation

/// A single row from the `played_tracks` table, read directly via
/// Supabase's REST API (PostgREST) — used by `HistoryViewModel` to backfill
/// "Co hrálo" gaps for stretches when the app wasn't open to observe a
/// track change itself. See `backend/supabase/sql/001_played_tracks.sql`.
struct RemotePlayedTrack: Decodable {
    let id: UUID
    let artist: String
    let title: String
    let playedAtString: String
    let showName: String?

    enum CodingKeys: String, CodingKey {
        case id, artist, title
        case playedAtString = "played_at"
        case showName = "show_name"
    }

    var playedAt: Date {
        Self.isoFormatterWithFraction.date(from: playedAtString)
            ?? Self.isoFormatter.date(from: playedAtString)
            ?? .distantPast
    }

    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()
}
