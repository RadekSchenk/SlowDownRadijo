import Combine
import Foundation
import PostHog
import UIKit

/// Anonymous product analytics: which parts of the app get used. One door
/// for the whole app (`Analytics.shared.track(_:)`); PostHog (EU cloud) is
/// behind it today, Google Analytics can join later without touching the
/// call sites. Event names and properties live in `AnalyticsEvent` and are
/// documented in `docs/analytics-events.md`.
///
/// **Consent first.** Nothing is sent until the listener says yes — the
/// gentle card on the home screen (`AnalyticsConsentCard`) or the switch in
/// Settings. PostHog starts opted out and is opted in only then.
///
/// **What it isn't.** Listening time per listener and show already lives in
/// the listening stats (Supabase) and is not duplicated here; no autocapture
/// of taps, no session replay, no surveys, no person profiles, no
/// swizzling (it would wrap our own notification delegate), no advertising
/// identifiers. The PostHog id is its own random id, unrelated to the
/// anonymous id of the listening stats.
@MainActor
final class Analytics: ObservableObject {
    static let shared = Analytics()

    enum Consent: String {
        case unknown, granted, denied
    }

    @Published private(set) var consent: Consent

    /// Public, write-only project key — made to ship inside apps.
    private static let projectToken = "phc_wQbQcZR2RkojLQUaCsokAx6wqnkr7sK5XqH37bKoaPUb"
    private static let host = "https://eu.i.posthog.com"
    /// Bumped when an event's meaning changes (see the event list).
    private static let schemaVersion = 1

    private static let consentKey = "analytics.consent"
    private static let launchCountKey = "analytics.launchCount"
    /// The consent card appears from this launch on — a first-time listener
    /// gets to know the app before being asked anything.
    private static let askFromLaunch = 3
    /// Coming back after this long counts as opening the app again.
    private static let reopenAfter: TimeInterval = 30 * 60

    private var isConfigured = false
    private var backgroundedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        consent = Consent(rawValue: UserDefaults.standard.string(forKey: Self.consentKey) ?? "") ?? .unknown
    }

    /// Call once at launch.
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        let config = PostHogConfig(projectToken: Self.projectToken, host: Self.host)
        config.optOut = consent != .granted
        config.enableSwizzling = false
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.personProfiles = .never
        config.sessionReplay = false
        config.surveys = false
        config.setBeforeSend(Self.stripDeviceDetails)
        PostHogSDK.shared.setup(config)
        applyConsentToSDK()

        let launches = UserDefaults.standard.integer(forKey: Self.launchCountKey) + 1
        UserDefaults.standard.set(launches, forKey: Self.launchCountKey)

        track(.appOpened(kind: "cold"))

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.backgroundedAt = Date() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self, let since = self.backgroundedAt,
                      Date().timeIntervalSince(since) >= Self.reopenAfter else { return }
                self.track(.appOpened(kind: "warm"))
            }
            .store(in: &cancellables)
    }

    /// The SDK adds the exact hardware model ("iPhone16,1") and its name;
    /// the device type (phone / tablet) and OS version are enough for us.
    nonisolated private static func stripDeviceDetails(_ event: PostHogEvent) -> PostHogEvent? {
        event.properties.removeValue(forKey: "$device_model")
        event.properties.removeValue(forKey: "$device_name")
        return event
    }

    // MARK: - Consent

    /// Time to show the consent card: not asked yet, and not on the first
    /// couple of launches.
    var shouldAskForConsent: Bool {
        consent == .unknown && UserDefaults.standard.integer(forKey: Self.launchCountKey) >= Self.askFromLaunch
    }

    var isEnabled: Bool { consent == .granted }

    func setConsent(_ granted: Bool) {
        consent = granted ? .granted : .denied
        UserDefaults.standard.set(consent.rawValue, forKey: Self.consentKey)
        applyConsentToSDK()
        if granted {
            // So the session the listener agreed in counts too.
            track(.appOpened(kind: "consent"))
        } else {
            // Drop what was queued and forget the id.
            PostHogSDK.shared.reset()
            applyConsentToSDK()
        }
    }

    private func applyConsentToSDK() {
        let sdk = PostHogSDK.shared
        if consent == .granted, sdk.isOptOut() {
            sdk.optIn()
        } else if consent != .granted, !sdk.isOptOut() {
            sdk.optOut()
        }
    }

    // MARK: - Events

    func track(_ event: AnalyticsEvent) {
        guard isConfigured, consent == .granted else { return }
        var properties = event.properties
        properties["language"] = LocalizationManager.shared.language.rawValue
        properties["schema_version"] = Self.schemaVersion
        PostHogSDK.shared.capture(event.name, properties: properties)
    }

    func screen(_ name: AnalyticsScreen) {
        track(.screenViewed(name))
    }
}

/// Screens as they appear in the data.
enum AnalyticsScreen: String {
    case home, message, stats, support, menu, settings, showReminders = "show_reminders", news
}

/// Every event the app sends — names and properties in one place, the same
/// for iOS and (later) Android. No free text, no song titles, nothing that
/// leads to a person; durations are rounded.
enum AnalyticsEvent {
    /// `kind`: "cold" (launch), "warm" (back after 30+ minutes), "consent".
    case appOpened(kind: String)
    case screenViewed(AnalyticsScreen)
    case languageChanged(to: String)

    /// `trigger`: see `RadioPlayerService.PlayTrigger`.
    case playbackStarted(trigger: String, showID: String?, connectMilliseconds: Int?)
    /// `reason`: see `RadioPlayerService.StopReason`.
    case playbackStopped(seconds: Int, reason: String, showID: String?, reconnects: Int)
    /// `stage`: "connecting" (never started) or "interrupted" (dropped while playing).
    case playbackFailed(stage: String, showID: String?)
    case sleepTimerSet(option: String)

    /// `source`: "bell" (Pořady list) or "settings".
    case showReminderChanged(showID: String, isOn: Bool, source: String)
    case showNotificationOpened(showID: String?, listen: Bool)
    case spotifyOpened(showID: String?)
    /// `target`: "whatsapp", "youtube", "threads", "instagram", "facebook".
    case linkOpened(target: String)

    case statsOpened(communityUnlocked: Bool)
    case supportLinkOpened(platform: String)
    case messageSent(success: Bool, seconds: Int)
    case feedbackSent(success: Bool)

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .screenViewed: return "screen_viewed"
        case .languageChanged: return "language_changed"
        case .playbackStarted: return "playback_started"
        case .playbackStopped: return "playback_stopped"
        case .playbackFailed: return "playback_failed"
        case .sleepTimerSet: return "sleep_timer_set"
        case .showReminderChanged: return "show_reminder_changed"
        case .showNotificationOpened: return "show_notification_opened"
        case .spotifyOpened: return "spotify_opened"
        case .linkOpened: return "link_opened"
        case .statsOpened: return "stats_opened"
        case .supportLinkOpened: return "support_link_opened"
        case .messageSent: return "message_sent"
        case .feedbackSent: return "feedback_sent"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appOpened(let kind):
            return ["kind": kind]
        case .screenViewed(let screen):
            return ["screen": screen.rawValue]
        case .languageChanged(let to):
            return ["to": to]
        case .playbackStarted(let trigger, let showID, let connectMilliseconds):
            var properties: [String: Any] = ["trigger": trigger, "show_id": showID ?? "_"]
            if let connectMilliseconds { properties["connect_ms"] = connectMilliseconds }
            return properties
        case .playbackStopped(let seconds, let reason, let showID, let reconnects):
            return [
                "seconds_listened": Self.rounded(seconds),
                "end_reason": reason,
                "show_id": showID ?? "_",
                "reconnects": reconnects,
            ]
        case .playbackFailed(let stage, let showID):
            return ["stage": stage, "show_id": showID ?? "_"]
        case .sleepTimerSet(let option):
            return ["option": option]
        case .showReminderChanged(let showID, let isOn, let source):
            return ["show_id": showID, "on": isOn, "source": source]
        case .showNotificationOpened(let showID, let listen):
            return ["show_id": showID ?? "_", "listen": listen]
        case .spotifyOpened(let showID):
            return ["show_id": showID ?? "_"]
        case .linkOpened(let target):
            return ["target": target]
        case .statsOpened(let communityUnlocked):
            return ["community_unlocked": communityUnlocked]
        case .supportLinkOpened(let platform):
            return ["platform": platform]
        case .messageSent(let success, let seconds):
            return ["success": success, "duration_s": Self.rounded(seconds, to: 5)]
        case .feedbackSent(let success):
            return ["success": success]
        }
    }

    /// Rounded to the nearest `step` seconds (10 by default).
    private static func rounded(_ seconds: Int, to step: Int = 10) -> Int {
        max(0, Int((Double(seconds) / Double(step)).rounded()) * step)
    }
}
