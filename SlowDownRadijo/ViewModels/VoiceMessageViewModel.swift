import Foundation

enum VoiceMessageState: Equatable {
    case ready
    case recording
    case recorded(url: URL, duration: TimeInterval)
    case sent
}

@MainActor
final class VoiceMessageViewModel: ObservableObject {
    @Published private(set) var state: VoiceMessageState = .ready
    @Published var permissionDeniedAlert = false

    let recorder: VoiceMessageRecorder
    private let radioPlayer: RadioPlayerService

    init(radioPlayer: RadioPlayerService, recorder: VoiceMessageRecorder? = nil) {
        self.radioPlayer = radioPlayer
        self.recorder = recorder ?? VoiceMessageRecorder()
        self.recorder.onMaxDurationReached = { [weak self] url, duration in
            self?.state = .recorded(url: url, duration: duration)
        }
    }

    var recordingURL: URL? {
        switch state {
        case .recorded(let url, _): return url
        case .ready, .recording, .sent: return nil
        }
    }

    var recordingDuration: TimeInterval {
        switch state {
        case .recorded(_, let duration): return duration
        case .ready, .recording, .sent: return 0
        }
    }

    func startRecording() {
        Task {
            let granted = await recorder.requestPermissionIfNeeded()
            guard granted else {
                permissionDeniedAlert = true
                return
            }
            // Recording through the same shared audio session as the live
            // stream would either conflict or bleed radio audio into the
            // mic — pause playback first.
            radioPlayer.pause()
            do {
                try recorder.startRecording()
                state = .recording
            } catch {
                state = .ready
            }
        }
    }

    func stopRecording() {
        guard let result = recorder.stopRecording() else { return }
        state = .recorded(url: result.url, duration: result.duration)
    }

    func cancelRecording() {
        if case .recording = state, let result = recorder.stopRecording() {
            recorder.discardRecording(at: result.url)
        }
        radioPlayer.reactivatePlaybackAudioSession()
        state = .ready
    }

    func retry() {
        if let url = recordingURL {
            recorder.discardRecording(at: url)
        }
        startRecording()
    }

    func togglePlayback() {
        guard let url = recordingURL else { return }
        recorder.togglePlayback(url: url)
    }

    /// Stops any preview playback and hands back the recording's file URL
    /// so `MessageView` can present the system share sheet — there's no
    /// network upload anymore (see `ActivityShareSheet`'s doc comment for
    /// why). `nil` if there's no recording to share.
    func beginSharing() -> URL? {
        guard case .recorded(let url, _) = state else { return nil }
        recorder.stopPlayback()
        return url
    }

    /// Called once the share sheet presented from `beginSharing()`'s URL
    /// closes. `completed` is `false` if the user cancelled/dismissed it
    /// without picking a share target — in that case the recording is
    /// still intact and the "recorded" screen stays up so they can retry.
    func finishSharing(completed: Bool) {
        guard case .recorded(let url, _) = state, completed else { return }
        recorder.discardRecording(at: url)
        radioPlayer.reactivatePlaybackAudioSession()
        state = .sent
    }

    func recordAnother() {
        state = .ready
    }
}
