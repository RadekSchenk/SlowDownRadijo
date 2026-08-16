import AVFoundation

/// Records a short voice message to a local temp file and can play it back
/// for preview. The resulting file is handed to `VoiceMessageUploadService`
/// by `VoiceMessageViewModel` once the user taps send.
@MainActor
final class VoiceMessageRecorder: NSObject, ObservableObject {
    static let maxDuration: TimeInterval = 60
    static let waveformSegmentCount = 18

    /// Fires once, from `tick()`, when recording auto-stops after hitting
    /// `maxDuration` — the only way `VoiceMessageViewModel` learns that
    /// happened, since `stopRecording()` at that point is called internally
    /// rather than in response to the user tapping stop.
    var onMaxDurationReached: ((URL, TimeInterval) -> Void)?

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Fixed-size array of peak levels (0...1), one per segment of the full
    /// `maxDuration` — segments ahead of the current recording position stay
    /// at 0, matching the Figma waveform's "progress through the 3-minute
    /// max" look rather than a scrolling real-time meter.
    @Published private(set) var waveformLevels = [Float](repeating: 0, count: waveformSegmentCount)

    @Published private(set) var isPlaying = false
    @Published private(set) var playbackProgress: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?

    func requestPermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.isMeteringEnabled = true
        newRecorder.record()

        recorder = newRecorder
        recordingURL = url
        elapsed = 0
        waveformLevels = [Float](repeating: 0, count: Self.waveformSegmentCount)
        isRecording = true

        recordTimer?.invalidate()
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        elapsed += 0.1

        let normalized = Self.normalizedLevel(fromDecibels: recorder.averagePower(forChannel: 0))
        let progress = min(elapsed / Self.maxDuration, 1)
        let index = min(Int(progress * Double(Self.waveformSegmentCount)), Self.waveformSegmentCount - 1)
        waveformLevels[index] = max(waveformLevels[index], normalized)

        if elapsed >= Self.maxDuration, let result = stopRecording() {
            onMaxDurationReached?(result.url, result.duration)
        }
    }

    /// Stops recording and returns the file + duration, or `nil` if nothing
    /// was recording.
    @discardableResult
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard isRecording, let recorder, let url = recordingURL else { return nil }
        recorder.stop()
        recordTimer?.invalidate()
        recordTimer = nil
        isRecording = false
        self.recorder = nil
        return (url, elapsed)
    }

    func discardRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func normalizedLevel(fromDecibels db: Float) -> Float {
        let minDb: Float = -50
        guard db.isFinite else { return 0 }
        let clamped = max(db, minDb)
        return (clamped - minDb) / -minDb
    }

    // MARK: - Playback preview

    func togglePlayback(url: URL) {
        if isPlaying {
            stopPlayback()
        } else {
            play(url: url)
        }
    }

    private func play(url: URL) {
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.delegate = self
        newPlayer.play()
        player = newPlayer
        isPlaying = true

        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
    }
}

extension VoiceMessageRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stopPlayback()
        }
    }
}
