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
        let granted = await requestAuthorizationIfNeeded()

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

    /// Called both from the periodic check above and directly when the
    /// user flips the toggle on in `NotificationsView`, so permission gets
    /// asked for right away rather than waiting for the next new post.
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

    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        static let shared = ForegroundPresenter()

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .badge]
        }
    }
}
