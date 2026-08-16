import Foundation

enum VoiceMessageState: Equatable {
    case ready
    case recording
    case recorded(url: URL, duration: TimeInterval)
    case sending(url: URL, duration: TimeInterval)
    case sent
}

@MainActor
final class VoiceMessageViewModel: ObservableObject {
    @Published private(set) var state: VoiceMessageState = .ready
    @Published var permissionDeniedAlert = false
    @Published var uploadFailedAlert = false

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
        case .recorded(let url, _), .sending(let url, _): return url
        case .ready, .recording, .sent: return nil
        }
    }

    var recordingDuration: TimeInterval {
        switch state {
        case .recorded(_, let duration), .sending(_, let duration): return duration
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

    /// Uploads the recording to our relay endpoint (see
    /// `VoiceMessageUploadService`), which forwards it as an email — no
    /// system mail composer, no user-visible mail step.
    func submit() {
        guard case .recorded(let url, let duration) = state else { return }
        recorder.stopPlayback()
        state = .sending(url: url, duration: duration)

        Task {
            do {
                try await VoiceMessageUploadService.upload(fileURL: url)
                recorder.discardRecording(at: url)
                radioPlayer.reactivatePlaybackAudioSession()
                state = .sent
            } catch {
                uploadFailedAlert = true
                state = .recorded(url: url, duration: duration)
            }
        }
    }

    func recordAnother() {
        state = .ready
    }
}
