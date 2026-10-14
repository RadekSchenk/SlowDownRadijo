import Combine
import Foundation

/// Turns the player's state changes into listening events: one
/// `playback_started` when audio actually begins (with how long the
/// connection took and what started it), one `playback_stopped` when the
/// listener's session ends (time actually heard, why it ended, how many
/// reconnects happened in between), and `playback_failed` when the stream
/// doesn't start or drops. A dropout the player recovers from is part of
/// the same session.
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

    init(player: RadioPlayerService, currentShowID: @escaping () -> String?) {
        self.player = player
        self.currentShowID = currentShowID
        cancellable = player.$state
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handle(state) }
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
                    connectMilliseconds: connectMilliseconds
                ))
            } else if droppedInSession {
                droppedInSession = false
                reconnects += 1
            }
            playingSince = now
            failureReported = false

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
            Analytics.shared.track(.playbackStopped(
                seconds: Int(heardSeconds),
                reason: player.lastStopReason.rawValue,
                showID: currentShowID(),
                reconnects: reconnects
            ))
        }
    }

    private func pausePlayingClock(at now: Date) {
        if let since = playingSince {
            heardSeconds += now.timeIntervalSince(since)
            playingSince = nil
        }
    }
}
