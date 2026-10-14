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
        /// "The Best of Slow Down" has a bundled hero photo instead of a
        /// real per-show image — same special case as the home hero.
        let usesBundledHeroImage: Bool
        let seconds: Int
        let fraction: Double
    }

    var todaySeconds = 0
    var totalSeconds = 0
    var communitySeconds = 0
    var rank: Int?
    var rankedListeners = 0
    /// The last seven days, oldest first, today last.
    var bars: [DayBar] = []
    var weekSeconds = 0
    var weekRangeLabel = ""
    /// This week's shows, most listened first.
    var shows: [ShowShare] = []
}
