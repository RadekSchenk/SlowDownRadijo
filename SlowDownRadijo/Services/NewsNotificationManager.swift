import Foundation
import UserNotifications

/// Best-effort local notification when a new "Novinka" appears — checked
/// once per app launch (see `RootTabView`), not true background push:
/// that would need our own server sending silent APNs pushes, which this
/// project deliberately doesn't have. Good enough to surface a new post
/// the next time the app is opened; a post published while the app has
/// been closed for a while won't page until then.
enum NewsNotificationManager {
    private static let preferenceKey = "newsNotificationsEnabled"
    private static let lastSeenPostIDKey = "news.lastSeenPostID"

    /// Mirrors `@AppStorage("newsNotificationsEnabled")`'s default — reads
    /// made outside a SwiftUI view (like this manager) don't get that
    /// default for free, since `@AppStorage` never actually writes it to
    /// `UserDefaults` until the user changes it.
    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: preferenceKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    static func checkForNewPost() async {
        guard isEnabled else { return }
        // Never asks at launch: permission is asked in context (the news
        // switch, a show's bell); until then new posts just aren't announced.
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let granted = status == .authorized || status == .provisional

        guard let posts = try? await NewsService.fetchRecent(limit: 1), let latest = posts.first else { return }

        let defaults = UserDefaults.standard
        guard let lastSeenID = defaults.object(forKey: lastSeenPostIDKey) as? Int else {
            // First run ever — seed the baseline without notifying about
            // everything that was already published before the app existed.
            defaults.set(latest.id, forKey: lastSeenPostIDKey)
            return
        }
        guard latest.id != lastSeenID else { return }
        defaults.set(latest.id, forKey: lastSeenPostIDKey)

        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.newsNotificationTitle
        content.body = latest.title
        content.sound = .default

        let request = UNNotificationRequest(identifier: "news-\(latest.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Called from `NewsListView` — when it opens with the switch on (the
    /// default) and when the switch is flipped on — so permission is asked
    /// where it makes sense, not at launch.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// The check above runs at launch, i.e. almost always while the app is
    /// in the foreground — without this, iOS suppresses the banner
    /// entirely for foreground notifications, so it would never actually
    /// be seen. Call once at app startup.
    static func configureForegroundPresentation() {
        UNUserNotificationCenter.current().delegate = ForegroundPresenter.shared
    }

    /// Uses the completion-handler callbacks, not the `async` ones: an
    /// `async` delegate method runs off the main thread and iOS then calls
    /// its own completion there too, which UIKit answers with an assertion
    /// crash (seen when opening a show notification). Here the work and the
    /// completion both happen on the main thread.
    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        static let shared = ForegroundPresenter()

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound, .badge])
        }

        /// A tap on a show-start notification (`ShowReminderStore`): the
        /// home tab, and the radio too for "Poslouchat".
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            let content = response.notification.request.content
            guard content.categoryIdentifier == ShowReminderStore.categoryID else {
                completionHandler()
                return
            }
            let listen = response.actionIdentifier == ShowReminderStore.listenActionID
            let showID = content.userInfo["showID"] as? String
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    ShowReminderStore.shared.requestOpen(listen: listen, showID: showID)
                }
                completionHandler()
            }
        }
    }
}
