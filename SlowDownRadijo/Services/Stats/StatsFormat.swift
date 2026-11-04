import Foundation

/// Number and duration formatting for the stats screens, following the
/// app language: Czech groups thousands with a (non-breaking) space and uses
/// a decimal comma ("1 238 424", "1,5 h"), English with commas and a point.
enum StatsFormat {
    private static var locale: Locale {
        Locale(identifier: LocalizationManager.shared.language == .cs ? "cs_CZ" : "en_US")
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Whole days, the remaining whole hours and minutes (seconds are
    /// dropped). Days only count from 24 hours on; below that `days` is 0.
    static func daysHoursAndMinutes(seconds: Int) -> (days: Int, hours: Int, minutes: Int) {
        let totalMinutes = max(seconds, 0) / 60
        let totalHours = totalMinutes / 60
        return (totalHours / 24, totalHours % 24, totalMinutes % 60)
    }

    /// "4 h 12 m", from 24 hours on "3 d 4 h 12 m"; under an hour just
    /// "45 m" (used inside badges and rows).
    static func duration(seconds: Int) -> String {
        let (days, hours, minutes) = daysHoursAndMinutes(seconds: seconds)
        let minutesPart = String(format: "%02d", minutes)
        if days > 0 { return "\(number(days)) d \(hours) h \(minutesPart) m" }
        if hours == 0 { return "\(minutes) m" }
        return "\(hours) h \(minutesPart) m"
    }

    /// Chart labels: "45 m", "1 h", "1,25 h", "2,5 h"; "0" for nothing.
    static func compactDuration(seconds: Int) -> String {
        guard seconds >= 60 else { return "0" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) m" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let hours = Double(minutes) / 60
        return "\(formatter.string(from: NSNumber(value: hours)) ?? "\(hours)") h"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }

    /// "28. 9. – 4. 10." / "Sep 28 – Oct 4".
    static func dateRange(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = LocalizationManager.shared.language == .cs ? "d. M." : "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
