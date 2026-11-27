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
    /// Listening is being counted right now — drives the live dot by "Dnes".
    @Published private(set) var isMeasuring = false

    private static let snapshotKey = "stats.snapshot"
    private static let publicKey = "stats.publicStats"
    private static let minimumRefreshGap: TimeInterval = 20

    private let scheduleStore: ScheduleStore
    private var lastRefresh = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    init(scheduleStore: ScheduleStore) {
        self.scheduleStore = scheduleStore

        // An earlier build remembered "unlocked" permanently under this key.
        UserDefaults.standard.removeObject(forKey: "stats.available")
        snapshot = Self.loadCached(StatsSnapshot.self, key: Self.snapshotKey)
        publicStats = Self.loadCached(PublicStats.self, key: Self.publicKey)
        isMeasuring = ListeningTracker.shared.isMeasuring
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
                case .measuringChanged:
                    self.isMeasuring = ListeningTracker.shared.isMeasuring
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
    #if DEBUG
    /// Store screenshots: sample numbers instead of the server's.
    func applyDemo(snapshot: StatsSnapshot, publicStats: PublicStats) {
        self.snapshot = snapshot
        self.publicStats = publicStats
    }
    #endif

    func refreshAll(force: Bool = false) async {
        #if DEBUG
        if StoreDemo.isOn { return }
        #endif
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
        // Settle an unconfirmed upload first (its `.synced` triggers the
        // refresh); until then the cached snapshot plus the local rows are
        // the consistent picture.
        if ListeningTracker.shared.hasUnconfirmedBatch {
            ListeningTracker.shared.retryUnconfirmedBatch()
            return
        }

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
        makeSummary(now: AppClock.now)
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
        var daySeconds: [Int] = []
        for date in days {
            let key = ListeningTracker.dayString(for: date)
            let shows = perDay[key] ?? [:]
            daySeconds.append(shows.values.reduce(0, +))
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

        // Shows over all time: the server's totals plus what this phone
        // hasn't sent yet. Without them (an older server, an old cached
        // snapshot), the recent days the snapshot holds.
        var allTimeSeconds: [String: Int] = [:]
        if let totals = snapshot?.shows {
            for total in totals { allTimeSeconds[total.showId, default: 0] += total.seconds }
            for row in unsynced { allTimeSeconds[row.showID, default: 0] += row.seconds }
        } else {
            for shows in perDay.values {
                for (id, seconds) in shows { allTimeSeconds[id, default: 0] += seconds }
            }
        }
        let showsSeconds = allTimeSeconds.values.reduce(0, +)
        let shows: [ListeningStatsSummary.ShowShare] = allTimeSeconds
            .filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { id, seconds in
                let show = scheduleStore.knownShow(id: id)
                return ListeningStatsSummary.ShowShare(
                    id: id,
                    name: show?.displayTitle ?? L10n.statsUnknownShow,
                    hostName: show?.hostName,
                    imageURL: show?.imageURL,
                    artworkName: show?.artworkName,
                    seconds: seconds,
                    fraction: showsSeconds > 0 ? Double(seconds) / Double(showsSeconds) : 0
                )
            }

        let todayKey = ListeningTracker.dayString(for: now)
        let communityBase = snapshot?.communitySeconds ?? publicStats?.communitySeconds ?? 0
        var totalSeconds = (snapshot?.totalSeconds ?? 0) + unsyncedSeconds
        #if DEBUG
        // Screenshot tests: `-debugStatsTotalSeconds N` shows a long
        // listening history (days, not just hours) on a fresh install.
        totalSeconds += UserDefaults.standard.integer(forKey: "debugStatsTotalSeconds")
        #endif

        let periods = makePeriods(now: now, perDay: perDay, totalSeconds: totalSeconds)
        let streakDays = makeStreak(now: now, perDay: perDay)

        return ListeningStatsSummary(
            todaySeconds: (perDay[todayKey] ?? [:]).values.reduce(0, +),
            totalSeconds: totalSeconds,
            communitySeconds: communityBase + unsyncedSeconds,
            rank: snapshot?.rank,
            rankedListeners: snapshot?.rankedListeners ?? publicStats?.rankedListeners ?? 0,
            aheadSeconds: snapshot?.aheadSeconds,
            behindSeconds: snapshot?.behindSeconds,
            listeningDays: listeningDays(perDay: perDay),
            bars: bars,
            weekSeconds: weekSeconds,
            weekRangeLabel: StatsFormat.dateRange(from: days.first ?? now, to: days.last ?? now),
            shows: shows,
            showsSeconds: showsSeconds,
            periods: periods,
            streakDays: streakDays,
            lastWeekSeconds: snapshot?.lastWeek?.seconds ?? 0,
            lastWeekRank: snapshot?.lastWeek?.rank
        )
    }

    /// Weeks from Monday and calendar months, in Prague time.
    static let pragueCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    /// The server's standing per period (029) plus what this phone hasn't
    /// sent yet. Without it (an older server), the times from the recent
    /// days the snapshot holds, unranked, and all time as before.
    private func makePeriods(now: Date, perDay: [String: [String: Int]], totalSeconds: Int) -> [StatsPeriod: PeriodStanding] {
        let unsynced = ListeningTracker.shared.unsyncedRows
        let calendar = Self.pragueCalendar
        let weekKey = ListeningTracker.dayString(for: calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now)
        let monthKey = ListeningTracker.dayString(for: calendar.dateInterval(of: .month, for: now)?.start ?? now)
        func unsyncedSince(_ key: String) -> Int {
            unsynced.filter { $0.day >= key }.reduce(0) { $0 + $1.seconds }
        }
        func localSince(_ key: String) -> Int {
            perDay.filter { $0.key >= key }.values.reduce(0) { $0 + $1.values.reduce(0, +) }
        }
        func standing(_ rank: StatsSnapshot.PeriodRank, seconds: Int) -> PeriodStanding {
            PeriodStanding(
                seconds: seconds,
                previousSeconds: rank.previousSeconds,
                rank: rank.rank,
                ranked: rank.ranked ?? 0,
                isOpen: rank.open ?? false,
                aheadSeconds: rank.aheadSeconds,
                behindSeconds: rank.behindSeconds
            )
        }

        guard let server = snapshot?.periods else {
            return [
                .week: PeriodStanding(seconds: localSince(weekKey)),
                .month: PeriodStanding(seconds: localSince(monthKey)),
                .all: PeriodStanding(
                    seconds: totalSeconds,
                    rank: snapshot?.rank,
                    ranked: snapshot?.rankedListeners ?? 0,
                    isOpen: snapshot?.rank != nil,
                    aheadSeconds: snapshot?.aheadSeconds,
                    behindSeconds: snapshot?.behindSeconds
                ),
            ]
        }
        var result: [StatsPeriod: PeriodStanding] = [:]
        if let week = server.week { result[.week] = standing(week, seconds: week.seconds + unsyncedSince(weekKey)) }
        if let month = server.month { result[.month] = standing(month, seconds: month.seconds + unsyncedSince(monthKey)) }
        if let all = server.all { result[.all] = standing(all, seconds: totalSeconds) }
        return result
    }

    /// Days in a row up to today or yesterday: the server's run, plus today
    /// when only this phone knows about it yet; without it, counted from the
    /// days the snapshot holds.
    private func makeStreak(now: Date, perDay: [String: [String: Int]]) -> Int {
        let calendar = Calendar.current
        let today = ListeningTracker.dayString(for: now)
        let yesterday = ListeningTracker.dayString(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        let listenedToday = (perDay[today] ?? [:]).values.reduce(0, +) > 0
        if let days = snapshot?.streakDays {
            let through = snapshot?.streakThrough
            if through == today || !listenedToday { return through == nil ? 0 : days }
            return through == yesterday ? days + 1 : 1
        }
        var count = 0
        var date = listenedToday ? now : (calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        while (perDay[ListeningTracker.dayString(for: date)] ?? [:]).values.reduce(0, +) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }

    /// The server's count, plus today when only this phone knows about it
    /// yet; without the server's number, the days this phone has seen.
    private func listeningDays(perDay: [String: [String: Int]]) -> Int {
        let daysWithListening = Set(perDay.filter { $0.value.values.reduce(0, +) > 0 }.keys)
        guard let server = snapshot?.listeningDays else { return daysWithListening.count }
        let serverDays = Set((snapshot?.daily ?? []).filter { $0.seconds > 0 }.map(\.day))
        return server + daysWithListening.subtracting(serverDays).count
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
