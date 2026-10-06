import Foundation

/// Toggles for features that are fully implemented but currently hidden
/// from the app. The code behind a `false` flag is deliberately left in
/// place rather than deleted — flipping the flag back to `true` is meant
/// to be the entire job of bringing a feature back.
enum FeatureFlags {
    /// "Právě hraje" (now-playing track row) and "Co hrálo" (recent-plays
    /// list) on the home screen, plus the "Oblíbené" tab — which only
    /// existed to show/manage tracks favorited from those two lists and
    /// has no reason to exist without them. Turned off 2026-10-06 at
    /// RadekSchenk's request.
    static let nowPlayingHistoryAndFavorites = false

    /// The standalone "Program" tab (`ProgramView`) — turned off
    /// 2026-10-06 once `HomeProgramSection` put full day-by-day schedule
    /// browsing directly on the home screen, making the separate tab
    /// redundant. `ProgramView` itself is untouched, just unreachable from
    /// the tab bar.
    static let standaloneProgramTab = false
}
