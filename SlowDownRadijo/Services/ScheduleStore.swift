import Foundation

/// The weekly programme, and "what's on right now" for a given date/time.
///
/// The week comes from slowdownradijo.cz (`WebScheduleService`), so a
/// special broadcast the station puts on the web shows in the app too. The
/// last week fetched is kept on disk; before the first fetch, or offline
/// on a first launch, the programme bundled as `schedule.json` stands in.
/// The bundled file is also the catalogue of the station's regular shows
/// (hosts, photos, descriptions) that the web's week is matched against.
///
/// Every instance (the app's, the reminders', the widget's) shows the same
/// week: a refresh anywhere updates them all.
final class ScheduleStore: ObservableObject {
    /// The schedule's times are the station's own (Prague) local time, the
    /// same zone `collect-now-playing` resolves shows in — not the phone's,
    /// so a listener abroad still sees what is really on air.
    static let stationCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
        return calendar
    }()

    @Published private(set) var days: [ScheduleDay] = []

    /// How long a fetched week counts as fresh.
    static let refreshInterval: TimeInterval = 15 * 60
    private static let didUpdate = Notification.Name("ScheduleStore.didUpdate")

    private var observer: NSObjectProtocol?

    init() {
        days = Self.state.withLock { $0.days } ?? Self.bundledDays
        observer = NotificationCenter.default.addObserver(forName: Self.didUpdate, object: nil, queue: .main) { [weak self] note in
            guard let days = note.object as? [ScheduleDay] else { return }
            self?.days = days
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - The bundled programme

    /// `schedule.json`: the programme shipped with the app.
    static let bundledDays: [ScheduleDay] = {
        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "json") else {
            assertionFailure("schedule.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let schedule = try JSONDecoder().decode(Schedule.self, from: data)
            return schedule.days.sorted { $0.weekday < $1.weekday }
        } catch {
            assertionFailure("Failed to decode schedule.json: \(error)")
            return []
        }
    }()

    /// Every regular show once, from the bundled programme.
    static let catalog: [Show] = {
        var seen = Set<String>()
        return bundledDays.flatMap(\.shows).filter { seen.insert($0.id).inserted }
    }()

    /// The show with `id` in this week's programme or among the regular
    /// shows — for the listening stats, which outlive a special broadcast.
    func knownShow(id: String) -> Show? {
        for day in days {
            if let show = day.shows.first(where: { $0.id == id }) { return show }
        }
        return Self.catalog.first { $0.id == id } ?? Self.state.withLock { $0.formerShows[id] }
    }

    // MARK: - Following the web

    private struct State {
        /// The week last fetched or read from disk; `nil` before either.
        var days: [ScheduleDay]?
        var fetchedAt = Date.distantPast
        var isFetching = false
        /// Shows from earlier weeks that aren't regulars (specials), kept
        /// so their name and photo stay known once they're off the week.
        var formerShows: [String: Show] = [:]
    }

    private static let state: LockedValue<State> = {
        var state = State()
        if let cache = readCache() {
            state.days = cache.days
            state.formerShows = Dictionary(cache.formerShows.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        }
        return LockedValue(state)
    }()

    /// Fetches the week from the web unless it was fetched in the last
    /// `refreshInterval` (`force` skips that). On failure the programme
    /// stays as it was.
    func refresh(force: Bool = false) async {
        let shouldFetch = Self.state.withLock { state -> Bool in
            guard !state.isFetching else { return false }
            guard force || Date().timeIntervalSince(state.fetchedAt) > Self.refreshInterval else { return false }
            state.isFetching = true
            return true
        }
        guard shouldFetch else { return }

        let fetched = try? await WebScheduleService.fetch(catalog: Self.catalog)
        let cache = Self.state.withLock { state -> CachedWeek? in
            state.isFetching = false
            guard let fetched else { return nil }
            state.fetchedAt = Date()
            let regulars = Set(Self.catalog.map(\.id))
            var formerChanged = false
            for show in fetched.flatMap(\.shows) where !regulars.contains(show.id) && state.formerShows[show.id] == nil {
                state.formerShows[show.id] = show
                formerChanged = true
            }
            guard fetched != state.days || formerChanged else { return nil }
            state.days = fetched
            return CachedWeek(days: fetched, formerShows: Array(state.formerShows.values))
        }
        guard let fetched else { return }
        if let cache { Self.writeCache(cache) }
        await MainActor.run {
            if self.days != fetched {
                NotificationCenter.default.post(name: Self.didUpdate, object: fetched)
            }
        }
    }

    // MARK: - The week on disk

    private struct CachedWeek: Codable {
        let days: [ScheduleDay]
        let formerShows: [Show]
    }

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("schedule-web.json")
    }

    private static func readCache() -> CachedWeek? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(CachedWeek.self, from: data),
              cache.days.count == 7 else { return nil }
        return CachedWeek(days: cache.days.sorted { $0.weekday < $1.weekday }, formerShows: cache.formerShows)
    }

    private static func writeCache(_ cache: CachedWeek) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func day(for weekday: Int) -> ScheduleDay? {
        days.first { $0.weekday == weekday }
    }

    /// Returns the show scheduled at `date`, if the schedule fully covers that slot.
    func currentShow(at date: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> Show? {
        let weekday = calendar.component(.weekday, from: date)
        guard let day = day(for: weekday) else { return nil }
        let minutes = minuteOfDay(for: date, calendar: calendar)

        return day.shows.first { show in
            guard let start = Self.minutes(from: show.start),
                  let rawEnd = Self.minutes(from: show.end) else { return false }
            let end = rawEnd == 0 ? 1440 : rawEnd
            return minutes >= start && minutes < end
        }
    }

    /// Resolves the show that was airing at an arbitrary past `date`, used to
    /// annotate "Co hrálo" history entries with the programme block they aired in.
    func show(at date: Date, calendar: Calendar = ScheduleStore.stationCalendar) -> Show? {
        currentShow(at: date, calendar: calendar)
    }

    /// Fraction (0...1) of `show`'s scheduled block that has elapsed at `date`.
    /// Returns 0 if `show`'s times can't be parsed or the block has zero length.
    func progress(for show: Show, at date: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> Double {
        guard let start = Self.minutes(from: show.start),
              let rawEnd = Self.minutes(from: show.end) else { return 0 }
        let end = rawEnd == 0 ? 1440 : rawEnd
        guard end > start else { return 0 }

        let startSeconds = start * 60
        let endSeconds = end * 60
        let elapsedSeconds = secondOfDay(for: date, calendar: calendar) - startSeconds
        let totalSeconds = endSeconds - startSeconds

        return min(max(Double(elapsedSeconds) / Double(totalSeconds), 0), 1)
    }

    /// Whole minutes remaining in `show`'s scheduled block at `date`.
    func remainingMinutes(for show: Show, at date: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> Int {
        guard let rawEnd = Self.minutes(from: show.end) else { return 0 }
        let end = rawEnd == 0 ? 1440 : rawEnd
        let endSeconds = end * 60
        let remaining = endSeconds - secondOfDay(for: date, calendar: calendar)
        return max(0, remaining) / 60
    }

    /// The show scheduled immediately after `show` — the next block on the
    /// same day, or the following day's first block if `show` runs to
    /// midnight. `date` should be a moment within `show`'s own block.
    func nextShow(after show: Show, from date: Date, calendar: Calendar = ScheduleStore.stationCalendar) -> Show? {
        let weekday = calendar.component(.weekday, from: date)
        guard let scheduleDay = day(for: weekday) else { return nil }

        if let index = scheduleDay.shows.firstIndex(where: { $0.id == show.id && $0.start == show.start }),
           index + 1 < scheduleDay.shows.count {
            return scheduleDay.shows[index + 1]
        }

        // `show` was the day's last block (ends at midnight) — the next one
        // is tomorrow's first block. Calendar weekday is 1(Sun)...7(Sat).
        let nextWeekday = weekday == 7 ? 1 : weekday + 1
        return day(for: nextWeekday)?.shows.first
    }

    /// The absolute moment `show` ends, anchored to today's date (relative
    /// to `date`) — used by the sleep timer's "Konec pořadu" option. `nil`
    /// if `show.end` can't be parsed.
    /// The absolute moment `show` started, anchored to today's date
    /// (relative to `date`). `nil` if `show.start` can't be parsed.
    func startDate(for show: Show, relativeTo date: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> Date? {
        guard let start = Self.minutes(from: show.start) else { return nil }
        return calendar.date(byAdding: .minute, value: start, to: calendar.startOfDay(for: date))
    }

    func endDate(for show: Show, relativeTo date: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> Date? {
        guard let rawEnd = Self.minutes(from: show.end) else { return nil }
        let totalMinutes = rawEnd == 0 ? 1440 : rawEnd
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: totalMinutes, to: startOfDay)
    }

    private func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func secondOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }

    private static func minutes(from timeString: String) -> Int? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }
}

/// A value behind a lock, for the state every `ScheduleStore` shares.
private final class LockedValue<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
