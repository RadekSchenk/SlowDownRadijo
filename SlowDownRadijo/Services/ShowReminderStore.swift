import Combine
import Foundation
import UIKit
import UserNotifications

/// "Upozorni mě, až pořad začne": the shows the listener follows, and the
/// local notifications for their starts. The schedule ships with the app,
/// so everything is planned on the phone — no server, no account, works
/// offline. A notification fires at the exact start (Prague time), titled
/// "Právě začíná" with the show's name, plus a "Poslouchat" action that
/// opens the app and starts the radio.
///
/// iOS keeps at most 64 pending notifications per app, and a week has
/// more slots than that, so only the nearest `maxScheduled` starts are
/// queued; the queue is rebuilt on launch, on every return to the
/// foreground and whenever a reminder or the language changes.
@MainActor
final class ShowReminderStore: ObservableObject {
    static let shared = ShowReminderStore()

    enum ToggleOutcome {
        case enabled
        case disabled
        /// The listener said no to notifications (now or earlier).
        case notAllowed
    }

    /// What a tap on a show notification asked for — `RootTabView` acts on
    /// it (home tab, and playback for "Poslouchat") and clears it.
    enum OpenRequest {
        case open
        case listen
    }

    @Published private(set) var followedIDs: Set<String>
    @Published var openRequest: OpenRequest?
    /// The show whose notification was tapped (for analytics).
    var openedShowID: String?

    nonisolated static let categoryID = "SHOW_START"
    nonisolated static let listenActionID = "LISTEN"
    private static let storageKey = "showReminders.followed"
    private static let identifierPrefix = "show-start-"
    /// Leaves a few of iOS's 64 slots for the news notification.
    private static let maxScheduled = 60
    private static let lookaheadDays = 14

    private let schedule = ScheduleStore()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        followedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? [])

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.reschedule() }
            .store(in: &cancellables)

        // Notification texts follow the app's language.
        LocalizationManager.shared.$language
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                // `$language` fires before the new value is stored.
                DispatchQueue.main.async {
                    Self.registerNotificationCategory()
                    self?.reschedule()
                }
            }
            .store(in: &cancellables)
    }

    /// Registers the "Poslouchat" action. Call once at app start.
    nonisolated static func registerNotificationCategory() {
        let listen = UNNotificationAction(
            identifier: listenActionID,
            title: L10n.listenAction,
            options: [.foreground]
        )
        let category = UNNotificationCategory(identifier: categoryID, actions: [listen], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Following

    func isFollowing(_ show: Show) -> Bool {
        followedIDs.contains(show.id)
    }

    /// Every show in the schedule once, by title — for Settings.
    var allShows: [Show] {
        var seen = Set<String>()
        var shows: [Show] = []
        for day in schedule.days {
            for show in day.shows where seen.insert(show.id).inserted {
                shows.append(show)
            }
        }
        return shows.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    func toggle(_ show: Show) async -> ToggleOutcome {
        await setFollowing(show, !isFollowing(show))
    }

    /// Asks for notification permission the first time a show is followed
    /// (in context, not at launch).
    func setFollowing(_ show: Show, _ follow: Bool) async -> ToggleOutcome {
        guard follow else {
            followedIDs.remove(show.id)
            save()
            reschedule()
            return .disabled
        }
        guard await NewsNotificationManager.requestAuthorizationIfNeeded() else {
            return .notAllowed
        }
        followedIDs.insert(show.id)
        save()
        reschedule()
        return .enabled
    }

    func unfollowAll() {
        followedIDs.removeAll()
        save()
        reschedule()
    }

    private func save() {
        UserDefaults.standard.set(Array(followedIDs).sorted(), forKey: Self.storageKey)
    }

    // MARK: - Next airing

    /// The show's next start after `now`, e.g. "zítra v 09:00" — for the
    /// confirmation toast.
    func nextAiringLabel(for show: Show, now: Date = Date()) -> String? {
        guard let start = upcomingStarts(for: [show.id], from: now).first?.start else { return nil }
        let calendar = ScheduleStore.stationCalendar
        let day: String
        if calendar.isDate(start, inSameDayAs: now) {
            day = L10n.today.lowercased()
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(start, inSameDayAs: tomorrow) {
            day = L10n.tomorrow
        } else {
            day = L10n.shortDayName(weekday: calendar.component(.weekday, from: start))
        }
        return L10n.nextAiring(day: day, time: show.start)
    }

    // MARK: - Scheduling

    func reschedule() {
        let followed = followedIDs
        let starts = upcomingStarts(for: followed, from: Date()).prefix(Self.maxScheduled)
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let old = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)

            guard !starts.isEmpty else { return }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            for (show, start) in starts {
                let content = UNMutableNotificationContent()
                content.title = L10n.showStartingTitle
                content.body = show.localizedName
                content.sound = .default
                content.categoryIdentifier = Self.categoryID
                content.threadIdentifier = Self.categoryID
                content.userInfo = ["showID": show.id]

                let interval = max(1, start.timeIntervalSinceNow)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let identifier = "\(Self.identifierPrefix)\(show.id)-\(Int(start.timeIntervalSince1970))"
                try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
        }
    }

    /// Starts of the given shows over the next `lookaheadDays`, soonest
    /// first, in Prague time. A slot that merely continues the same show
    /// (back-to-back blocks, or across midnight) isn't a new start.
    private func upcomingStarts(for ids: Set<String>, from now: Date) -> [(show: Show, start: Date)] {
        guard !ids.isEmpty else { return [] }
        let calendar = ScheduleStore.stationCalendar
        let today = calendar.startOfDay(for: now)
        var result: [(show: Show, start: Date)] = []
        var previous: (id: String, end: Date)?

        // Start a day early so a show continuing past midnight into today
        // is recognised as a continuation.
        for offset in -1..<Self.lookaheadDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let day = schedule.day(for: calendar.component(.weekday, from: date)) else { continue }

            let slots = day.shows.compactMap { show -> (show: Show, start: Date, end: Date)? in
                guard let start = Self.date(date, at: show.start, calendar: calendar),
                      let end = Self.date(date, at: show.end, calendar: calendar, endOfDay: true) else { return nil }
                return (show, start, end)
            }
            .sorted { $0.start < $1.start }

            for slot in slots {
                let continues = previous.map { $0.id == slot.show.id && $0.end == slot.start } ?? false
                previous = (slot.show.id, slot.end)
                if !continues, ids.contains(slot.show.id), slot.start > now {
                    result.append((slot.show, slot.start))
                }
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    /// `"HH:mm"` on `day`; with `endOfDay`, `"00:00"`/`"24:00"` means the
    /// following midnight.
    private static func date(_ day: Date, at time: String, calendar: Calendar, endOfDay: Bool = false) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let (hour, minute) = (parts[0], parts[1])
        if endOfDay, (hour == 0 || hour == 24), minute == 0 {
            return calendar.date(byAdding: .day, value: 1, to: day)
        }
        guard (0..<24).contains(hour) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}
