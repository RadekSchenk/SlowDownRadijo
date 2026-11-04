import Foundation

/// When the home screen asks iOS for its App Store rating dialog
/// (`requestReview`). Straight to the system dialog, with no question of
/// our own first: App Review rejects apps that ask whether you like them
/// and send only the happy ones to rate (guideline 5.6.1).
///
/// Only listeners who keep coming back are asked: at least a week since
/// the app was first opened and at least three days with 10+ minutes of
/// listening in the last 60. After a request it rests for 120 days, at
/// most three times in all. iOS itself shows the dialog at most three
/// times a year, however often it's requested, and not at all to someone
/// who has already rated.
///
/// Everything here stays in `UserDefaults` on the phone; nothing is sent.
@MainActor
final class ReviewPrompt: ObservableObject {
    static let shared = ReviewPrompt()

    @Published private(set) var shouldAsk = false

    private static let firstOpenKey = "reviewPrompt.firstOpen"
    private static let listeningKey = "reviewPrompt.listeningByDay"
    private static let lastAskedKey = "reviewPrompt.lastAsked"
    private static let timesAskedKey = "reviewPrompt.timesAsked"
    /// Set by the earlier "do you like the app?" card on a yes — those
    /// listeners were already sent to the rating.
    private static let likedKey = "reviewPrompt.liked"

    private static let minimumAge: TimeInterval = 7 * 86_400
    private static let qualifyingDaySeconds: TimeInterval = 10 * 60
    private static let qualifyingDays = 3
    private static let window = 60
    private static let rest: TimeInterval = 120 * 86_400
    private static let maximumAsks = 3

    private let defaults = UserDefaults.standard
    /// Seconds listened per calendar day ("yyyy-MM-dd"), last `window` days.
    private var listeningByDay: [String: Double]

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        listeningByDay = defaults.dictionary(forKey: Self.listeningKey) as? [String: Double] ?? [:]
        if defaults.object(forKey: Self.firstOpenKey) == nil {
            defaults.set(Date(), forKey: Self.firstOpenKey)
        }
        evaluate()
    }

    /// Called by `PlaybackAnalytics` as listening time accrues.
    func addListening(seconds: TimeInterval, at date: Date = Date()) {
        guard seconds > 0 else { return }
        let day = Self.dayFormatter.string(from: date)
        listeningByDay[day, default: 0] += seconds
        // Keep only the window.
        if let cutoff = Calendar.current.date(byAdding: .day, value: -Self.window, to: date) {
            let oldest = Self.dayFormatter.string(from: cutoff)
            listeningByDay = listeningByDay.filter { $0.key >= oldest }
        }
        defaults.set(listeningByDay, forKey: Self.listeningKey)
        evaluate()
    }

    /// The rating dialog was requested (iOS decides whether it shows).
    func didAsk() {
        defaults.set(Date(), forKey: Self.lastAskedKey)
        defaults.set(defaults.integer(forKey: Self.timesAskedKey) + 1, forKey: Self.timesAskedKey)
        shouldAsk = false
    }

    private func evaluate() {
        let now = Date()
        let firstOpen = defaults.object(forKey: Self.firstOpenKey) as? Date ?? now
        let lastAsked = defaults.object(forKey: Self.lastAskedKey) as? Date
        let qualifying = listeningByDay.values.filter { $0 >= Self.qualifyingDaySeconds }.count

        shouldAsk = !defaults.bool(forKey: Self.likedKey)
            && defaults.integer(forKey: Self.timesAskedKey) < Self.maximumAsks
            && now.timeIntervalSince(firstOpen) >= Self.minimumAge
            && lastAsked.map { now.timeIntervalSince($0) >= Self.rest } ?? true
            && qualifying >= Self.qualifyingDays
    }
}
