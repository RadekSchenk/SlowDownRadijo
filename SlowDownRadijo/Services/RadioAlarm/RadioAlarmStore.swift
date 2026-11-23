import AppIntents
import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// "Budík s rádiem" (Figma "Budík s rádiem", docs/radio-alarm.md): at the
/// set time the system alarm rings (AlarmKit, iOS 26+, even in silent
/// mode). "Pustit rádio" stops it, opens the app and starts the live
/// stream; "Odložit" is the system's snooze. With the radio playing, the
/// home screen offers snoozing again: the radio pauses and a one-off alarm
/// rings after the snooze time.
///
/// iOS can't start the stream without that tap — AlarmKit plays an alarm
/// sound, not the app's audio. On iOS 17–25 the feature isn't shown.
struct RadioAlarmSettings: Codable, Equatable {
    var isOn = false
    var hour = 6
    var minute = 30
    /// `Calendar` weekdays (1 = Sunday … 7 = Saturday); empty = once.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var snoozeMinutes = 9
    /// When a one-off alarm (no weekdays) rings; it switches itself off after.
    var onceAt: Date?

    static let snoozeChoices = [5, 9, 10, 15]
}

@MainActor
final class RadioAlarmStore: ObservableObject {
    static let shared = RadioAlarmStore()

    enum Authorization { case notDetermined, authorized, denied }

    @Published private(set) var settings: RadioAlarmSettings
    @Published private(set) var authorization: Authorization = .notDetermined
    /// The radio was started by the alarm at this moment (the "Dobré ráno"
    /// card for 15 minutes).
    @Published private(set) var wokeAt: Date?
    /// Snoozed from the app: the radio plays again at this moment.
    @Published private(set) var snoozedUntil: Date?
    @Published private(set) var snoozeCount = 0

    /// After this many snoozes from the app, it just plays.
    static let maxSnoozes = 3
    private static let settingsKey = "radioAlarm.settings"
    private static let alarmIDKey = "radioAlarm.id"
    private static let snoozeIDKey = "radioAlarm.snoozeID"

    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(RadioAlarmSettings.self, from: data) {
            settings = saved
        } else {
            settings = RadioAlarmSettings()
        }
    }

    // MARK: - Settings

    /// Turns the alarm on (asking for permission the first time) or off.
    func setOn(_ on: Bool) async {
        var next = settings
        next.isOn = on
        if on, !(await authorize()) { next.isOn = false }
        await apply(next)
    }

    func update(_ change: (inout RadioAlarmSettings) -> Void) async {
        var next = settings
        change(&next)
        await apply(next)
    }

    /// On launch and when the app comes back: a one-off alarm that has rung
    /// switches off; a repeating one is scheduled again if iOS lost it.
    func sync() async {
        guard Self.isSupported else { return }
        refreshAuthorization()
        if settings.isOn, settings.weekdays.isEmpty, let onceAt = settings.onceAt, onceAt < Date() {
            var next = settings
            next.isOn = false
            next.onceAt = nil
            save(next)
            return
        }
        if settings.isOn, authorization == .authorized, !isScheduled { await schedule() }
        if let wokeAt, Date().timeIntervalSince(wokeAt) > 15 * 60 { self.wokeAt = nil }
        if let snoozedUntil, snoozedUntil < Date() { self.snoozedUntil = nil }
    }

    private func apply(_ next: RadioAlarmSettings) async {
        var next = next
        next.onceAt = next.isOn && next.weekdays.isEmpty ? Self.nextFire(after: Date(), settings: next) : nil
        save(next)
        await schedule()
    }

    private func save(_ next: RadioAlarmSettings) {
        settings = next
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    // MARK: - Waking up

    /// "Pustit rádio" on the alarm (`PlayRadioAlarmIntent`), or the time
    /// to play again after snoozing from the app.
    func wake() {
        wokeAt = Date()
        snoozedUntil = nil
        AppServices.shared.player.play(trigger: .alarm)
        if settings.weekdays.isEmpty, settings.isOn {
            var next = settings
            next.isOn = false
            next.onceAt = nil
            save(next)
        }
    }

    /// "Odložit" on the home card: the radio pauses, a one-off alarm rings
    /// after the snooze time.
    func snooze() async {
        AppServices.shared.player.pause()
        snoozeCount += 1
        let until = Date().addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
        snoozedUntil = until
        wokeAt = nil
        await scheduleOnce(at: until, idKey: Self.snoozeIDKey)
    }

    func cancelSnooze() {
        snoozedUntil = nil
        snoozeCount = 0
        cancel(idKey: Self.snoozeIDKey)
    }

    /// "Hotovo": the morning card goes, the radio keeps playing.
    func done() {
        wokeAt = nil
        snoozeCount = 0
    }

    /// "Vyzkoušet za 10 sekund".
    func test() async {
        guard await authorize() else { return }
        await scheduleOnce(at: Date().addingTimeInterval(10), idKey: Self.snoozeIDKey)
    }

    var canSnooze: Bool { snoozeCount < Self.maxSnoozes }

    // MARK: - Times

    /// The next time the alarm rings, from `date`.
    static func nextFire(after date: Date, settings: RadioAlarmSettings, calendar: Calendar = .current) -> Date? {
        var components = DateComponents(hour: settings.hour, minute: settings.minute)
        if settings.weekdays.isEmpty {
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        }
        return settings.weekdays.compactMap { weekday -> Date? in
            components.weekday = weekday
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        }.min()
    }

    var nextFire: Date? {
        settings.isOn ? (settings.onceAt ?? Self.nextFire(after: Date(), settings: settings)) : nil
    }

    // MARK: - AlarmKit

    private var isScheduled: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), let id = Self.storedID(Self.alarmIDKey) {
            return (try? AlarmManager.shared.alarms.contains { $0.id == id }) ?? false
        }
        #endif
        return false
    }

    private func refreshAuthorization() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized: authorization = .authorized
            case .denied: authorization = .denied
            default: authorization = .notDetermined
            }
        }
        #endif
    }

    private func authorize() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = (try? await AlarmManager.shared.requestAuthorization()) ?? AlarmManager.shared.authorizationState
            refreshAuthorization()
            return state == .authorized
        }
        #endif
        return false
    }

    private func schedule() async {
        cancel(idKey: Self.alarmIDKey)
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), settings.isOn, authorization == .authorized else { return }
        let when: Alarm.Schedule
        if settings.weekdays.isEmpty {
            guard let onceAt = settings.onceAt else { return }
            when = .fixed(onceAt)
        } else {
            let days = settings.weekdays.sorted().compactMap { Self.localeWeekday($0) }
            when = .relative(.init(time: .init(hour: settings.hour, minute: settings.minute), repeats: .weekly(days)))
        }
        await schedule(when, idKey: Self.alarmIDKey)
        #endif
    }

    private func scheduleOnce(at date: Date, idKey: String) async {
        cancel(idKey: idKey)
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        await schedule(.fixed(date), idKey: idKey)
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func schedule(_ schedule: Alarm.Schedule, idKey: String) async {
        let id = UUID()
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: L10n.alarmTitle),
            stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L10n.alarmStopButton), textColor: .white, systemImageName: "radio"),
            secondaryButton: AlarmButton(text: LocalizedStringResource(stringLiteral: L10n.alarmSnoozeButton), textColor: .white, systemImageName: "zzz"),
            secondaryButtonBehavior: .countdown
        )
        let presentation = AlarmPresentation(
            alert: alert,
            countdown: .init(title: LocalizedStringResource(stringLiteral: L10n.alarmSnoozedTitle))
        )
        let attributes = AlarmAttributes<RadioAlarmMetadata>(presentation: presentation, metadata: RadioAlarmMetadata(), tintColor: Theme.liveRed)
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: TimeInterval(settings.snoozeMinutes * 60)),
            schedule: schedule,
            attributes: attributes,
            stopIntent: PlayRadioAlarmIntent(),
            secondaryIntent: nil
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            UserDefaults.standard.set(id.uuidString, forKey: idKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: idKey)
        }
    }

    @available(iOS 26.0, *)
    private static func localeWeekday(_ weekday: Int) -> Locale.Weekday? {
        [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][safe: weekday - 1]
    }
    #endif

    private func cancel(idKey: String) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), let id = Self.storedID(idKey) {
            try? AlarmManager.shared.cancel(id: id)
        }
        #endif
        UserDefaults.standard.removeObject(forKey: idKey)
    }

    private static func storedID(_ key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }
}

/// "Pustit rádio" on the ringing alarm: stops it, opens the app and plays
/// the live stream.
@available(iOS 26.0, *)
struct PlayRadioAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pustit rádio"
    static var openAppWhenRun = true
    static var isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RadioAlarmStore.shared.wake()
        return .result()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
