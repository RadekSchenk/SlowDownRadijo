import AVFoundation
import Combine
import Foundation

/// Turns the player's state changes into listening events: one
/// `playback_started` when audio actually begins (with how long the
/// connection took and what started it), one `playback_stopped` when the
/// listener's session ends (time actually heard, why it ended, how many
/// reconnects happened in between), and `playback_failed` when the stream
/// doesn't start or drops. A dropout the player recovers from is part of
/// the same session.
///
/// A session the app never sees end — the app closed or killed while the
/// radio plays, which happens often — would lose its whole listening time
/// (a third of all sessions went missing that way). So the session is
/// saved at its start and every minute while it plays, and the next launch
/// sends the saved one as `playback_stopped` with reason "app_closed".
@MainActor
final class PlaybackAnalytics {
    private let player: RadioPlayerService
    private let currentShowID: () -> String?
    private var cancellable: AnyCancellable?

    /// A start was asked for and we're waiting for sound.
    private var connectingSince: Date?
    /// The session is under way (sound has been heard).
    private var isInSession = false
    private var playingSince: Date?
    private var heardSeconds: TimeInterval = 0
    private var reconnects = 0
    /// The stream dropped mid-session; the next sound is a reconnect.
    private var droppedInSession = false
    /// Reported this stretch of failures already (retries go error →
    /// connecting → error until something plays or the listener stops).
    private var failureReported = false
    /// The output kind last seen, for `output_changed`.
    private var outputKind = AudioOutput.kind()

    init(player: RadioPlayerService, currentShowID: @escaping () -> String?) {
        self.player = player
        self.currentShowID = currentShowID
        Self.sendUnfinishedSession()
        cancellable = player.$state
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handle(state) }
        routeObserver = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.routeChanged() }
    }

    private var routeObserver: AnyCancellable?

    private func routeChanged() {
        let kind = AudioOutput.kind()
        guard kind != outputKind else { return }
        Analytics.shared.track(.outputChanged(from: outputKind, to: kind, playing: player.state == .playing))
        outputKind = kind
    }

    private func handle(_ state: PlaybackState) {
        let now = Date()

        switch state {
        case .connecting:
            pausePlayingClock(at: now)
            if !isInSession, connectingSince == nil {
                connectingSince = now
            }

        case .playing:
            if !isInSession {
                isInSession = true
                heardSeconds = 0
                reconnects = 0
                droppedInSession = false
                let connectMilliseconds = connectingSince.map { Int(now.timeIntervalSince($0) * 1000) }
                connectingSince = nil
                Analytics.shared.track(.playbackStarted(
                    trigger: player.lastPlayTrigger.rawValue,
                    showID: currentShowID(),
                    connectMilliseconds: connectMilliseconds,
                    output: AudioOutput.kind()
                ))
            } else if droppedInSession {
                droppedInSession = false
                reconnects += 1
            }
            playingSince = now
            startReviewCredit(at: now)
            failureReported = false
            saveSession(at: now)

        case .error:
            pausePlayingClock(at: now)
            if isInSession { droppedInSession = true }
            // Only the first failure of a stretch counts, not every retry.
            guard !failureReported else { return }
            failureReported = true
            Analytics.shared.track(.playbackFailed(
                stage: isInSession ? "interrupted" : "connecting",
                showID: currentShowID()
            ))

        case .paused, .idle:
            pausePlayingClock(at: now)
            connectingSince = nil
            failureReported = false
            guard isInSession else { return }
            isInSession = false
            UserDefaults.standard.removeObject(forKey: Self.openSessionKey)
            Analytics.shared.track(.playbackStopped(
                seconds: Int(heardSeconds),
                reason: player.lastStopReason.rawValue,
                showID: currentShowID(),
                reconnects: reconnects,
                output: AudioOutput.kind()
            ))
        }
    }

    private func pausePlayingClock(at now: Date) {
        creditReviewPrompt(at: now)
        reviewCreditedUntil = nil
        reviewTimer?.invalidate()
        reviewTimer = nil
        if let since = playingSince {
            heardSeconds += now.timeIntervalSince(since)
            playingSince = nil
        }
        saveSession(at: now)
    }

    // MARK: - Sessions the app never saw end

    private static let openSessionKey = "analytics.openSession"

    private struct OpenSession: Codable {
        let seconds: Double
        let showID: String?
        let reconnects: Int
        let output: String
    }

    /// The session so far, for the next launch to send if this one never
    /// gets to.
    private func saveSession(at now: Date) {
        guard isInSession else { return }
        let session = OpenSession(
            seconds: heardSeconds + (playingSince.map { now.timeIntervalSince($0) } ?? 0),
            showID: currentShowID(),
            reconnects: reconnects,
            output: AudioOutput.kind()
        )
        UserDefaults.standard.set(try? JSONEncoder().encode(session), forKey: Self.openSessionKey)
    }

    private static func sendUnfinishedSession() {
        guard let data = UserDefaults.standard.data(forKey: openSessionKey) else { return }
        UserDefaults.standard.removeObject(forKey: openSessionKey)
        guard let session = try? JSONDecoder().decode(OpenSession.self, from: data) else { return }
        Analytics.shared.track(.playbackStopped(
            seconds: Int(session.seconds),
            reason: "app_closed",
            showID: session.showID,
            reconnects: session.reconnects,
            output: session.output
        ))
    }

    /// Listening time for `ReviewPrompt` (local only, nothing is sent):
    /// credited every minute while playing, so a session that never
    /// "ends" (the app is closed while playing) still counts.
    private var reviewCreditedUntil: Date?
    private var reviewTimer: Timer?

    private func startReviewCredit(at now: Date) {
        reviewCreditedUntil = now
        reviewTimer?.invalidate()
        reviewTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                let now = Date()
                self?.creditReviewPrompt(at: now)
                self?.saveSession(at: now)
            }
        }
    }

    private func creditReviewPrompt(at now: Date) {
        guard let since = reviewCreditedUntil else { return }
        ReviewPrompt.shared.addListening(seconds: now.timeIntervalSince(since), at: now)
        reviewCreditedUntil = now
    }
}
