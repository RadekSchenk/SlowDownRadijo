import Combine
import Foundation
import UIKit

/// Everything the Statistiky tab and the home-screen block show, in one place.
///
/// * **Unlocking.** The listener's own stats are always there (zeros at first).
///   Only the community features — the leaderboard and the "everyone together"
///   total — wait until the server says enough people have listened
///   (`public_stats().available`, 20 listeners by default). The app simply
///   follows the server's latest answer; the last one is cached, so an offline
///   start shows the same thing as before.
/// * **Numbers.** The server snapshot (`get_my_stats`, cached for offline) plus
///   whatever this phone measured but hasn't uploaded yet, so "Dnes" keeps
///   ticking up live and is never behind.
/// * **No accounts from looking.** Opening the screen never creates the
///   anonymous account; only actually listening does.
@MainActor
final class ListeningStatsStore: ObservableObject {
    @Published private(set) var snapshot: StatsSnapshot?
    @Published private(set) var publicStats: PublicStats?
    /// The last attempt to reach the server failed (offline, server trouble).
    @Published private(set) var loadFailed = false
    @Published private(set) var isLoading = false

    private static let snapshotKey = "stats.snapshot"
    private static let publicKey = "stats.publicStats"
    private static let minimumRefreshGap: TimeInterval = 20

    private let showLookup: [String: Show]
    private var lastRefresh = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    init(scheduleStore: ScheduleStore) {
        var lookup: [String: Show] = [:]
        for day in scheduleStore.days {
            for show in day.shows where lookup[show.id] == nil {
                lookup[show.id] = show
            }
        }
        showLookup = lookup

        // An earlier build remembered "unlocked" permanently under this key.
        UserDefaults.standard.removeObject(forKey: "stats.available")
        snapshot = Self.loadCached(StatsSnapshot.self, key: Self.snapshotKey)
        publicStats = Self.loadCached(PublicStats.self, key: Self.publicKey)
        recordDebug("start: cached public available=\(publicStats.map { "\($0.available)" } ?? "none"), snapshot available=\(snapshot.map { "\($0.available)" } ?? "none")")

        ListeningTracker.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .accrued:
                    // Re-render so the numbers tick up while playing.
                    self.objectWillChange.send()
                case .synced:
                    Task { await self.refresh(force: true) }
                case .deleted:
                    self.clearLocalCache()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshAll() }
            }
            .store(in: &cancellables)

        Task { await refreshAll() }
    }

    // MARK: - Loading

    /// Community unlock state + numbers (cheap, anonymous), then — if measuring
    /// is on — this listener's own snapshot.
    func refreshAll(force: Bool = false) async {
        await refreshPublic()
        await refresh(force: force)
    }

    private func refreshPublic() async {
        guard let data = try? await StatsAPIClient.shared.fetchPublicStats() else {
            recordDebug("public_stats: request failed")
            return
        }
        guard let stats = Self.decode(PublicStats.self, from: data) else {
            recordDebug("public_stats: could not decode \(String(data: data, encoding: .utf8) ?? "?")")
            return
        }
        publicStats = stats
        Self.store(stats, key: Self.publicKey)
        recordDebug("public_stats: available=\(stats.available), ranked=\(stats.rankedListeners)")
    }

    /// One line for the DEBUG-only footer in Settings, so "why is the
    /// leaderboard showing?" can be answered from the phone itself.
    private func recordDebug(_ message: String) {
        #if DEBUG
        let time = Date().formatted(date: .omitted, time: .standard)
        UserDefaults.standard.set("\(time) \(message)", forKey: Self.debugKey)
        #endif
    }

    static let debugKey = "stats.debugLine"

    func refresh(force: Bool = false) async {
        guard StatsConfig.isEnabled, !isLoading else { return }
        if !force, Date().timeIntervalSince(lastRefresh) < Self.minimumRefreshGap { return }

        isLoading = true
        defer { isLoading = false }
        do {
            // `nil`: this phone never uploaded anything, so there's no
            // account to ask about — local numbers alone are the truth.
            if let data = try await StatsAPIClient.shared.fetchMyStats(),
               let fresh = Self.decode(StatsSnapshot.self, from: data) {
                snapshot = fresh
                Self.store(fresh, key: Self.snapshotKey)
            }
            loadFailed = false
            lastRefresh = Date()
        } catch {
            loadFailed = true
        }
    }

    private func clearLocalCache() {
        snapshot = nil
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
        lastRefresh = .distantPast
        Task { await refreshPublic() }
    }

    // MARK: - Summary

    /// The leaderboard and the community total are unlocked (enough
    /// listeners). Follows the server's latest answer, falling back to the
    /// cached one while offline.
    var communityUnlocked: Bool {
        publicStats?.available ?? snapshot?.available ?? false
    }

    var summary: ListeningStatsSummary {
        makeSummary(now: Date())
    }

    private func makeSummary(now: Date) -> ListeningStatsSummary {
        let unsynced = ListeningTracker.shared.unsyncedRows
        let unsyncedSeconds = unsynced.reduce(0) { $0 + $1.seconds }

        // day → show → seconds, server rows first, then unsent ones.
        var perDay: [String: [String: Int]] = [:]
        for row in snapshot?.daily ?? [] {
            perDay[row.day, default: [:]][row.showId, default: 0] += row.seconds
        }
        for row in unsynced {
            perDay[row.day, default: [:]][row.showID, default: 0] += row.seconds
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let days: [Date] = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: startOfToday)
        }

        var bars: [ListeningStatsSummary.DayBar] = []
        var showSeconds: [String: Int] = [:]
        var daySeconds: [Int] = []
        for date in days {
            let key = ListeningTracker.dayString(for: date)
            let shows = perDay[key] ?? [:]
            daySeconds.append(shows.values.reduce(0, +))
            for (id, seconds) in shows { showSeconds[id, default: 0] += seconds }
        }
        let peakSeconds = daySeconds.max() ?? 0
        let peakIndex = peakSeconds > 0 ? daySeconds.firstIndex(of: peakSeconds) : nil
        for (index, date) in days.enumerated() {
            bars.append(.init(
                id: ListeningTracker.dayString(for: date),
                label: L10n.shortDayName(weekday: calendar.component(.weekday, from: date)),
                seconds: daySeconds[index],
                isPeak: index == peakIndex
            ))
        }

        let weekSeconds = daySeconds.reduce(0, +)
        let shows: [ListeningStatsSummary.ShowShare] = showSeconds
            .filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { id, seconds in
                let show = showLookup[id]
                return ListeningStatsSummary.ShowShare(
                    id: id,
                    name: show?.displayTitle ?? L10n.statsUnknownShow,
                    hostName: show?.hostName,
                    imageURL: show?.imageURL,
                    usesBundledHeroImage: id == "the-best-of-slow-down",
                    seconds: seconds,
                    fraction: weekSeconds > 0 ? Double(seconds) / Double(weekSeconds) : 0
                )
            }

        let todayKey = ListeningTracker.dayString(for: now)
        let communityBase = snapshot?.communitySeconds ?? publicStats?.communitySeconds ?? 0

        return ListeningStatsSummary(
            todaySeconds: (perDay[todayKey] ?? [:]).values.reduce(0, +),
            totalSeconds: (snapshot?.totalSeconds ?? 0) + unsyncedSeconds,
            communitySeconds: communityBase + unsyncedSeconds,
            rank: snapshot?.rank,
            rankedListeners: snapshot?.rankedListeners ?? publicStats?.rankedListeners ?? 0,
            bars: bars,
            weekSeconds: weekSeconds,
            weekRangeLabel: StatsFormat.dateRange(from: days.first ?? now, to: days.last ?? now),
            shows: shows
        )
    }

    // MARK: - Persistence

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(type, from: data)
    }

    private static func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadCached<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return decode(type, from: data)
    }
}
