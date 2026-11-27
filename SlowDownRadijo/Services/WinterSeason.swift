import Foundation

/// "Zimní vzhled" (Figma "Advent ❄︎", docs/winter.md): from the first
/// Sunday of Advent to Epiphany (6 January, inclusive) the home header
/// snows and the logo's sun hangs as a Christmas bauble, and the first
/// launch of each day gets a winter splash — with a short wish on
/// 24–26 December. Dates are Prague's. The listener can turn it off in
/// Settings, and that choice stays for the following years too.
///
/// The winter app icon is not switched here: iOS would show an alert each
/// time. It is the app's icon in the release that brings the season
/// (`ASSETCATALOG_COMPILER_APPICON_NAME` in project.yml).
enum WinterSeason {
    /// The listener's switch in Settings (on unless turned off).
    static let enabledKey = "winterLookEnabled"
    /// Launch arguments for screenshots and tests, e.g.
    /// `-winterLookPreview YES`: today counts as a winter day;
    /// `-winterLookChristmasPreview YES`: and as Christmas.
    static let previewKey = "winterLookPreview"
    static let christmasPreviewKey = "winterLookChristmasPreview"
    /// The day (yyyy-MM-dd) the winter splash was last shown.
    private static let splashDayKey = "winterSplashLastDay"

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
        return calendar
    }()

    /// The first Sunday of Advent in `year`: four Sundays before
    /// Christmas, so between 27 November and 3 December.
    static func firstAdventSunday(year: Int) -> Date {
        let christmasEve = calendar.date(from: DateComponents(year: year, month: 12, day: 24))!
        // weekday: 1 = Sunday … 7 = Saturday.
        let back = calendar.component(.weekday, from: christmasEve) - 1
        return calendar.date(byAdding: .day, value: -back - 21, to: christmasEve)!
    }

    /// Advent to Epiphany, by the calendar alone.
    static func isSeason(_ date: Date) -> Bool {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = day.year, let month = day.month, let dayOfMonth = day.day else { return false }
        if month == 1 { return dayOfMonth <= 6 }
        guard month >= 11 else { return false }
        return date >= firstAdventSunday(year: year)
    }

    /// 24–26 December.
    static func isChristmas(_ date: Date) -> Bool {
        let day = calendar.dateComponents([.month, .day], from: date)
        return day.month == 12 && (24...26).contains(day.day ?? 0)
    }

    /// The season, or a preview of it.
    static func isWinter(_ date: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: previewKey) || isSeason(date)
    }

    /// The look is on: winter, and the listener hasn't turned it off.
    static func isOn(_ date: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        isWinter(date, defaults: defaults) && (defaults.object(forKey: enabledKey) as? Bool ?? true)
    }

    static func isChristmasNow(_ date: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: christmasPreviewKey) || isChristmas(date)
    }

    /// Whether this launch gets the winter splash: the look is on and it
    /// hasn't been shown today (once a day, so it never gets in the way).
    /// Marks today as done. A preview shows it every launch.
    static func takeSplash(_ date: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard isOn(date, defaults: defaults) else { return false }
        if defaults.bool(forKey: previewKey) { return true }
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let key = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        guard defaults.string(forKey: splashDayKey) != key else { return false }
        defaults.set(key, forKey: splashDayKey)
        return true
    }
}
