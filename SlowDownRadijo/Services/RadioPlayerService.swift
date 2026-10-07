import AVFoundation
import Combine
import MediaPlayer
import UIKit

enum PlaybackState: Equatable {
    case idle
    case connecting
    case playing
    case paused
    case error(String)
}

/// Owns the live audio stream: AVPlayer setup, background playback,
/// lock-screen / Control Center integration, and reconnect-on-drop logic.
///
/// Stream: https://icecast5.play.cz/slowdown.aac (confirmed on
/// slowdownradijo.cz/jak-si-nas-pustit/). We use the AAC stream rather than
/// the MP3 one (`http://icecast9.play.cz/slowdown.mp3`) because it is served
/// over HTTPS and needs no App Transport Security exception; the MP3 mount
/// only answers over plain HTTP.
final class RadioPlayerService: NSObject, ObservableObject {
    static let streamURL = URL(string: "https://icecast5.play.cz/slowdown.aac")!

    @Published private(set) var state: PlaybackState = .idle
    /// When set, playback will automatically pause at this moment — the
    /// "sleep timer" feature. `nil` means no timer is scheduled.
    @Published private(set) var sleepTimerFireDate: Date?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    /// Follows whether audio is actually coming out (`timeControlStatus`),
    /// so a stall that AVPlayer recovers from on its own brings the state
    /// back to `.playing` — `item.status` stays `.readyToPlay` throughout.
    private var timeControlObservation: NSKeyValueObservation?
    private var reconnectAttempt = 0
    private var reconnectTimer: Timer?
    /// Gives up on `.connecting` after `connectTimeout` and reconnects,
    /// instead of showing a spinner forever.
    private var connectTimeoutTimer: Timer?
    private static let connectTimeout: TimeInterval = 20
    private var stallObserver: NSObjectProtocol?
    private var sleepTimer: Timer?

    private var currentTrack: NowPlayingTrack?
    private var currentArtwork: UIImage?
    private var currentShowTitle: String = "Slow Down Rádijo"

    /// Set when a call, Siri, an alarm or another app took the audio session
    /// away from live playback, so the stream resumes when it's handed back.
    private var wasPlayingBeforeInterruption = false

    override init() {
        super.init()
        // Category only: activating a non-mixable session here would stop
        // other apps' audio the moment the app opens, even with autoplay off.
        configureAudioSession(activate: false)
        configureRemoteCommands()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        teardownPlayer()
        reconnectTimer?.invalidate()
        connectTimeoutTimer?.invalidate()
        sleepTimer?.invalidate()
    }

    // MARK: - Public API

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .idle, .paused, .error:
            play()
        case .connecting:
            break
        }
    }

    func play() {
        wasPlayingBeforeInterruption = false
        cancelReconnect()
        reconnectAttempt = 0
        startPlayback()
    }

    func pause() {
        wasPlayingBeforeInterruption = false
        // A reconnect scheduled after a dropout must not restart the stream
        // the listener (or the sleep timer) just paused.
        cancelReconnect()
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        player?.pause()
        state = .paused
        updateNowPlayingPlaybackRate(0)
    }

    /// Called by the view model whenever the parsed now-playing metadata or
    /// current-show artwork changes, so lock screen / Control Center stay in sync.
    func updateNowPlaying(track: NowPlayingTrack?, showTitle: String, artwork: UIImage?) {
        currentTrack = track
        currentShowTitle = showTitle
        currentArtwork = artwork
        publishNowPlayingInfo()
    }

    // MARK: - Sleep timer

    func scheduleSleepTimer(duration: TimeInterval) {
        scheduleSleepTimer(fireDate: Date().addingTimeInterval(duration))
    }

    func scheduleSleepTimer(fireDate: Date) {
        sleepTimer?.invalidate()
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else {
            pause()
            sleepTimerFireDate = nil
            return
        }
        sleepTimerFireDate = fireDate
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
                self?.sleepTimerFireDate = nil
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerFireDate = nil
    }

    /// Re-applies the `.playback` audio session category. The Vzkaz tab
    /// temporarily switches the shared `AVAudioSession` to `.playAndRecord`
    /// while recording a voice message; call this after it's done so
    /// background playback and lock-screen controls keep working correctly.
    func reactivatePlaybackAudioSession() {
        configureAudioSession(activate: true)
    }

    // MARK: - Playback lifecycle

    private func startPlayback() {
        configureAudioSession(activate: true)
        enterConnecting()
        teardownPlayer()

        let item = AVPlayerItem(url: Self.streamURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer
        playerItem = item

        observe(item: item)
        observe(player: newPlayer)
        newPlayer.play()
    }

    /// `.connecting` with a deadline: if audio doesn't (re)start within
    /// `connectTimeout`, treat it as a failure and reconnect.
    private func enterConnecting() {
        state = .connecting
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.connectTimeout, repeats: false) { [weak self] _ in
            guard let self, self.state == .connecting else { return }
            self.handleFailure()
        }
    }

    private func observe(player: AVPlayer) {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            DispatchQueue.main.async {
                guard let self, self.player === observedPlayer else { return }
                switch observedPlayer.timeControlStatus {
                case .playing:
                    self.connectTimeoutTimer?.invalidate()
                    self.connectTimeoutTimer = nil
                    self.reconnectAttempt = 0
                    if self.state != .playing {
                        self.state = .playing
                        self.updateNowPlayingPlaybackRate(1)
                    }
                case .waitingToPlayAtSpecifiedRate:
                    // A stall mid-stream; AVPlayer keeps trying by itself.
                    if self.state == .playing {
                        self.enterConnecting()
                    }
                case .paused:
                    // `pause()` and failures set the state themselves.
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func observe(item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                switch observedItem.status {
                case .readyToPlay:
                    self?.reconnectAttempt = 0
                    self?.state = .playing
                    self?.updateNowPlayingPlaybackRate(1)
                case .failed:
                    self?.handleFailure()
                default:
                    break
                }
            }
        }

        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.state == .playing else { return }
            self.enterConnecting()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemFailedToPlayToEndTime),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
    }

    /// The system silences the player during an interruption without
    /// telling `state`; mirror it as a pause (so the UI, lock screen and
    /// listening stats stop claiming "playing") and resume afterwards if the
    /// system says so.
    @objc private func audioSessionInterrupted(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                guard self.state == .playing || self.state == .connecting else { return }
                self.pause()
                self.wasPlayingBeforeInterruption = true
            case .ended:
                guard self.wasPlayingBeforeInterruption else { return }
                self.wasPlayingBeforeInterruption = false
                if shouldResume {
                    self.play()
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func itemFailedToPlayToEndTime() {
        handleFailure()
    }

    private func handleFailure() {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        state = .error(L10n.streamInterrupted)
        scheduleReconnect()
    }

    private func cancelReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectAttempt += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt)))
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.startPlayback()
        }
    }

    private func teardownPlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let observer = stallObserver {
            NotificationCenter.default.removeObserver(observer)
            stallObserver = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        player?.pause()
        player = nil
        playerItem = nil
    }

    // MARK: - Audio session (background playback)

    private func configureAudioSession(activate: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            if activate {
                try session.setActive(true)
            }
        } catch {
            print("AVAudioSession configuration error: \(error)")
        }
    }

    // MARK: - Remote command center (lock screen / Control Center)

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }

    // MARK: - MPNowPlayingInfoCenter

    private func publishNowPlayingInfo() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = currentTrack?.displayText ?? currentShowTitle
        info[MPMediaItemPropertyArtist] = "Slow Down Rádijo"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0

        // We don't have per-track album art for a live stream, so we fall
        // back to the current programme block's artwork, as specced.
        if let artwork = currentArtwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            info[MPMediaItemPropertyArtwork] = mpArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackRate(_ rate: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
