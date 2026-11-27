import Foundation

/// `get_my_stats()` — this listener's own numbers plus the community's.
/// Decoded with `.convertFromSnakeCase` (see `ListeningStatsStore`).
struct StatsSnapshot: Codable, Equatable {
    struct Row: Codable, Equatable {
        let day: String
        let showId: String
        let seconds: Int
    }

    let available: Bool
    let totalSeconds: Int
    let communitySeconds: Int
    let rankedListeners: Int
    /// `nil` until the listener has enough listening to be ranked.
    let rank: Int?
    let daily: [Row]
    /// Listening per show over all time (`get_my_stats`, 017). Missing from
    /// an older server or a snapshot cached before it.
    let shows: [ShowTotal]?
    /// Totals of the places right above and below `rank`, and the days with any listening (026). Anonymous numbers only;
    /// missing from an older server.
    var aheadSeconds: Int?
    var behindSeconds: Int?
    var listeningDays: Int?
    /// The leaderboard by period (029, Statistiky 1.4), last week, and the
    /// run of days. Missing from an older server.
    var periods: Periods?
    var lastWeek: LastWeek?
    var streakDays: Int?
    /// The last day of the run (yyyy-MM-dd): today or yesterday.
    var streakThrough: String?

    struct Periods: Codable, Equatable {
        let week: PeriodRank?
        let month: PeriodRank?
        let all: PeriodRank?
    }

    /// One period's place. `rank` is nil unless the listener has 10 min in
    /// it and the period has enough listeners (`open`); `ranked` only
    /// feeds the TOP % label and is never shown.
    struct PeriodRank: Codable, Equatable {
        let seconds: Int
        var previousSeconds: Int?
        var rank: Int?
        var ranked: Int?
        var open: Bool?
        var aheadSeconds: Int?
        var behindSeconds: Int?
    }

    struct LastWeek: Codable, Equatable {
        let seconds: Int
        var rank: Int?
    }

    struct ShowTotal: Codable, Equatable {
        let showId: String
        let seconds: Int
    }
}

/// `public_stats()` — needs no session, zeros until the stats UI unlocks.
struct PublicStats: Codable, Equatable {
    let available: Bool
    let communitySeconds: Int
    let rankedListeners: Int
}

/// Everything the Statistiky screen and the home block display, already
/// merged (server snapshot + what this phone has not uploaded yet).
struct ListeningStatsSummary {
    struct DayBar: Identifiable {
        let id: String
        let label: String
        let seconds: Int
        let isPeak: Bool
    }

    struct ShowShare: Identifiable {
        let id: String
        let name: String
        let hostName: String?
        let imageURL: URL?
        /// Bundled photo (`Show.artworkName`), preferred over `imageURL`.
        let artworkName: String?
        let seconds: Int
        let fraction: Double
    }

    var todaySeconds = 0
    var totalSeconds = 0
    var communitySeconds = 0
    var rank: Int?
    var rankedListeners = 0
    /// Total of the place right above (`nil` at #1 or unknown).
    var aheadSeconds: Int?
    /// Total of the place right below (`nil` when last or unknown).
    var behindSeconds: Int?
    /// Days with any listening.
    var listeningDays = 0
    /// The last seven days, oldest first, today last.
    var bars: [DayBar] = []
    var weekSeconds = 0
    var weekRangeLabel = ""
    /// Shows over all time, most listened first — not tied to the week in
    /// the chart.
    var shows: [ShowShare] = []
    /// All the time in `shows` together.
    var showsSeconds = 0
    /// The leaderboard for this week, this month and all time.
    var periods: [StatsPeriod: PeriodStanding] = [:]
    /// Days in a row with the radio, up to today or yesterday.
    var streakDays = 0
    /// Last week, for the card on Monday and Tuesday.
    var lastWeekSeconds = 0
    var lastWeekRank: Int?

    func period(_ period: StatsPeriod) -> PeriodStanding {
        periods[period] ?? PeriodStanding(seconds: period == .all ? totalSeconds : 0)
    }
}

/// The leaderboard's periods (Figma "Statistiky 1.4"): weeks Monday to
/// Sunday and calendar months, in Prague time.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, all
    var id: String { rawValue }
}

/// The listener in one period. `rank` is nil when they aren't ranked or
/// the period has too few listeners to show places at all (`isOpen`
/// false); then Statistiky shows their own time instead.
struct PeriodStanding: Equatable {
    var seconds: Int
    var previousSeconds: Int?
    var rank: Int?
    var ranked = 0
    var isOpen = false
    var aheadSeconds: Int?
    var behindSeconds: Int?
}
