import Foundation

/// Mirrors the JSON shape returned by the `get-stats` Edge Function (see
/// `backend/supabase/functions/get-stats`). This is radio-wide data,
/// collected server-side independent of whether the app is open — see
/// `backend/supabase/functions/collect-now-playing`.
struct StatsResponse: Decodable {
    let diversityWeekly: [WeeklyDiversity]
    let repetition: RepetitionStats?
    /// Total number of tracks making their global debut so far this week —
    /// the headline number for the "Poprvé na rádiu" digest.
    let firstPlaysWeekCount: Int
    /// A handful of this week's debuts to highlight — deliberately not the
    /// full list, see the "weekly digest" redesign (an unbounded list of
    /// every debut ever wasn't attractive or sustainable as a feature).
    let firstPlaysSample: [FirstPlay]
    /// Total distinct (artist, title) pairs ever recorded — gives the
    /// weekly count some scale ("12 new this week, 340 total").
    let totalUniqueTracks: Int
}

struct WeeklyDiversity: Decodable, Identifiable {
    let weekStartString: String
    let uniqueArtists: Int
    let firstTimeArtists: Int

    enum CodingKeys: String, CodingKey {
        case weekStartString = "week_start"
        case uniqueArtists = "unique_artists"
        case firstTimeArtists = "first_time_artists"
    }

    var id: String { weekStartString }

    /// Postgres returns a plain `date` (no time component) for this column.
    var weekStart: Date {
        Self.dateFormatter.date(from: weekStartString) ?? .distantPast
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

struct RepetitionStats: Decodable {
    let totalPlays: Int
    let repeatedPlays: Int
    let newPlays: Int
    let repetitionPct: Double

    enum CodingKeys: String, CodingKey {
        case totalPlays = "total_plays"
        case repeatedPlays = "repeated_plays"
        case newPlays = "new_plays"
        case repetitionPct = "repetition_pct"
    }
}

struct FirstPlay: Decodable, Identifiable {
    let artist: String
    let title: String
    let playedAtString: String

    enum CodingKeys: String, CodingKey {
        case artist, title
        case playedAtString = "played_at"
    }

    var id: String { "\(artist)-\(title)-\(playedAtString)" }

    var playedAt: Date {
        Self.isoFormatterWithFraction.date(from: playedAtString)
            ?? Self.isoFormatter.date(from: playedAtString)
            ?? .distantPast
    }

    var spotifySearchURL: URL? {
        SlowDownRadijo.spotifySearchURL(artist: artist, title: title)
    }

    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()
}
