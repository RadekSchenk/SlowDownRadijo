import Foundation

/// When to ask "do you like the app?" on the home screen
/// (`ReviewPromptCard`): yes leads to the App Store's own rating dialog,
/// no to the feedback form.
///
/// Only listeners who keep coming back are asked: at least a week since
/// the app was first opened and at least three days with 10+ minutes of
/// listening in the last 60. After an answer the question rests for 120
/// days, at most three times in all, and never again after a yes. iOS
/// itself shows the rating dialog at most three times a year, however
/// often it's requested.
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

    /// The listener answered the card.
    func answered(liked: Bool) {
        defaults.set(Date(), forKey: Self.lastAskedKey)
        defaults.set(defaults.integer(forKey: Self.timesAskedKey) + 1, forKey: Self.timesAskedKey)
        if liked { defaults.set(true, forKey: Self.likedKey) }
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
