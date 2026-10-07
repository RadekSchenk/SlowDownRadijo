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

    /// Whole hours and the remaining whole minutes (seconds are dropped).
    static func hoursAndMinutes(seconds: Int) -> (hours: Int, minutes: Int) {
        let totalMinutes = max(seconds, 0) / 60
        return (totalMinutes / 60, totalMinutes % 60)
    }

    /// "4 h 12 m"; under an hour just "45 m" (used inside badges and rows).
    static func duration(seconds: Int) -> String {
        let (hours, minutes) = hoursAndMinutes(seconds: seconds)
        if hours == 0 { return "\(minutes) m" }
        return "\(number(hours)) h \(String(format: "%02d", minutes)) m"
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
