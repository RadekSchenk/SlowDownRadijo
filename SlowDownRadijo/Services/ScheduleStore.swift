import Foundation

/// Loads the static weekly programme schedule bundled as `schedule.json` and
/// resolves "what's on right now" for a given date/time.
///
/// The schedule is hand-scraped from https://slowdownradijo.cz/program/ and
/// will drift out of date whenever the station changes its lineup — it is
/// **not** fetched live. Update `Resources/schedule.json` by re-running the
/// scrape when the programme changes.
final class ScheduleStore: ObservableObject {
    @Published private(set) var days: [ScheduleDay] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "json") else {
            assertionFailure("schedule.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let schedule = try JSONDecoder().decode(Schedule.self, from: data)
            days = schedule.days.sorted { $0.weekday < $1.weekday }
        } catch {
            assertionFailure("Failed to decode schedule.json: \(error)")
        }
    }

    func day(for weekday: Int) -> ScheduleDay? {
        days.first { $0.weekday == weekday }
    }

    /// Returns the show scheduled at `date`, if the schedule fully covers that slot.
    func currentShow(at date: Date = Date(), calendar: Calendar = .current) -> Show? {
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
    func show(at date: Date, calendar: Calendar = .current) -> Show? {
        currentShow(at: date, calendar: calendar)
    }

    /// Fraction (0...1) of `show`'s scheduled block that has elapsed at `date`.
    /// Returns 0 if `show`'s times can't be parsed or the block has zero length.
    func progress(for show: Show, at date: Date = Date(), calendar: Calendar = .current) -> Double {
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
    func remainingMinutes(for show: Show, at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let rawEnd = Self.minutes(from: show.end) else { return 0 }
        let end = rawEnd == 0 ? 1440 : rawEnd
        let endSeconds = end * 60
        let remaining = endSeconds - secondOfDay(for: date, calendar: calendar)
        return max(0, remaining) / 60
    }

    /// The show scheduled immediately after `show` — the next block on the
    /// same day, or the following day's first block if `show` runs to
    /// midnight. `date` should be a moment within `show`'s own block.
    func nextShow(after show: Show, from date: Date, calendar: Calendar = .current) -> Show? {
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

    /// The `count` shows scheduled after `show` (which must be the one
    /// airing at `now`), in schedule order — e.g. `count: 3` returns the
    /// very next show plus the two after that. Walks the week's schedule
    /// directly, crossing from one day into the next (and the one after
    /// that) as needed, rather than chaining `nextShow(after:from:)`
    /// calls, which only reason about a single step and would need a
    /// synthetic `date` to carry forward correctly across a day boundary.
    func upcomingShows(after show: Show, now: Date, count: Int, calendar: Calendar = .current) -> [Show] {
        guard count > 0 else { return [] }
        var weekday = calendar.component(.weekday, from: now)
        guard let currentDay = day(for: weekday),
              let startIndex = currentDay.shows.firstIndex(where: { $0.id == show.id && $0.start == show.start })
        else { return [] }

        var result: [Show] = []
        var dayShows = currentDay.shows
        var index = startIndex + 1
        var daysChecked = 0

        // `daysChecked <= 7` bounds this to at most one lap of the week,
        // in case the schedule is sparse enough that `count` can't be
        // filled (e.g. a weekday with no data at all).
        while result.count < count, daysChecked <= 7 {
            if index < dayShows.count {
                result.append(dayShows[index])
                index += 1
            } else {
                weekday = weekday == 7 ? 1 : weekday + 1
                daysChecked += 1
                guard let nextDay = day(for: weekday) else { continue }
                dayShows = nextDay.shows
                index = 0
            }
        }
        return result
    }

    /// The absolute moment `show` ends, anchored to today's date (relative
    /// to `date`) — used by the sleep timer's "Konec pořadu" option. `nil`
    /// if `show.end` can't be parsed.
    func endDate(for show: Show, relativeTo date: Date = Date(), calendar: Calendar = .current) -> Date? {
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
