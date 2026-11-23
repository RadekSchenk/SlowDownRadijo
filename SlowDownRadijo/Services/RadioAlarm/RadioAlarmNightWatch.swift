import AVFoundation
import Combine
import Foundation
import UserNotifications

/// Figma "Budík s rádiem" C4/C5: on iOS the radio itself wakes the listener
/// when the app is still running at the alarm's time.
///
/// AlarmKit only plays a sound file and can't start the app, so when the
/// alarm is less than 12 hours away and the radio isn't playing, the app
/// keeps a silent, mixable audio session going — nothing is downloaded and
/// other apps' audio isn't interrupted. That keeps it running in the
/// background (the `audio` background mode). At the alarm's time it calls
/// off the system alarm and starts the live stream (`RadioAlarmStore.ring`).
/// If the app was closed, iOS stopped it or the phone restarted, the system
/// alarm rings as before.
@MainActor
final class RadioAlarmNightWatch {
    static let shared = RadioAlarmNightWatch()

    /// How long before the alarm the app stays awake for it.
    private static let window: TimeInterval = 12 * 60 * 60

    private var silence: AVAudioPlayer?
    private var ringTimer: Timer?
    private var ringAt: Date?
    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    /// Once, at launch.
    func start() {
        guard RadioAlarmStore.isSupported, cancellables.isEmpty else { return }
        let store = RadioAlarmStore.shared
        let player = AppServices.shared.player
        player.$state.removeDuplicates().sink { [weak self] _ in self?.schedule() }.store(in: &cancellables)
        store.$settings.sink { [weak self] _ in self?.schedule() }.store(in: &cancellables)
        store.$snoozedUntil.sink { [weak self] _ in self?.schedule() }.store(in: &cancellables)
        store.$authorization.sink { [weak self] _ in self?.schedule() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if raw == AVAudioSession.InterruptionType.ended.rawValue { self?.schedule() }
            }
            .store(in: &cancellables)
    }

    /// The next time the radio should wake the listener: the end of a
    /// snooze, or the alarm.
    private var nextRing: (date: Date, endOfSnooze: Bool)? {
        let store = RadioAlarmStore.shared
        if let until = store.snoozedUntil, until > Date() { return (until, true) }
        if let fire = store.nextFire, fire > Date() { return (fire, false) }
        return nil
    }

    /// Runs after anything that changes when (or whether) to ring.
    func schedule() {
        let store = RadioAlarmStore.shared
        // Settings publish before they're stored; read them on the next turn.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard store.isAuthorized, let ring = self.nextRing,
                  ring.date.timeIntervalSinceNow < Self.window else {
                self.stopTimer()
                self.stopSilence()
                return
            }
            if self.ringAt != ring.date {
                self.ringTimer?.invalidate()
                self.ringAt = ring.date
                // A moment early, so the system alarm is called off in time.
                let timer = Timer(fire: ring.date.addingTimeInterval(-2), interval: 0, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.fire(endOfSnooze: ring.endOfSnooze) }
                }
                timer.tolerance = 0
                RunLoop.main.add(timer, forMode: .common)
                self.ringTimer = timer
            }
            switch AppServices.shared.player.state {
            case .playing: self.stopSilence()
            // Keep whatever runs: silence switched on now would make the
            // radio's session mixable mid-connect.
            case .connecting: break
            case .idle, .paused, .error: self.startSilence()
            }
        }
    }

    private func fire(endOfSnooze: Bool) {
        ringTimer = nil
        ringAt = nil
        Task {
            await RadioAlarmStore.shared.ring(endOfSnooze: endOfSnooze)
            schedule()
        }
    }

    private func stopTimer() {
        ringTimer?.invalidate()
        ringTimer = nil
        ringAt = nil
    }

    // MARK: - Silence

    private func startSilence() {
        if silence?.isPlaying == true { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.silentWAV)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            silence = player
        } catch {
            print("Radio alarm keep-awake failed: \(error)")
        }
    }

    private func stopSilence() {
        guard let silence else { return }
        silence.stop()
        self.silence = nil
        // The radio's own session takes over when it plays; otherwise let
        // the session go.
        if AppServices.shared.player.state != .playing, AppServices.shared.player.state != .connecting {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// One second of silence (8 kHz, 16-bit mono WAV).
    private static let silentWAV: Data = {
        let sampleRate: UInt32 = 8000
        let samples = Data(count: Int(sampleRate) * 2)
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + samples.count))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(sampleRate); append(sampleRate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(samples.count))
        data.append(samples)
        return data
    }()
}

/// The "Dobré ráno" notification when the radio started by itself: snooze
/// or turn the radio off from the lock screen. Only when notifications are
/// already allowed — the alarm doesn't ask for them.
enum RadioAlarmNotifier {
    static let categoryID = "radio-alarm"
    static let snoozeActionID = "radio-alarm.snooze"
    static let turnOffActionID = "radio-alarm.off"
    private static let requestID = "radio-alarm.good-morning"

    static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: snoozeActionID, title: L10n.alarmSnoozeButton),
                UNNotificationAction(identifier: turnOffActionID, title: L10n.alarmTurnOffRadio),
            ],
            intentIdentifiers: []
        )
    }

    static func postGoodMorning(canSnooze: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = L10n.alarmGoodMorning
            content.body = L10n.alarmPlayingNow
            content.categoryIdentifier = canSnooze ? categoryID : ""
            center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: nil))
        }
    }

    static func removeGoodMorning() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [requestID])
    }

    /// From the notification delegate (`NewsNotificationManager`).
    @MainActor
    static func handle(actionID: String) {
        switch actionID {
        case snoozeActionID:
            Task { await RadioAlarmStore.shared.snooze() }
        case turnOffActionID:
            AppServices.shared.player.pause()
            RadioAlarmStore.shared.done()
        default:
            break
        }
    }
}
