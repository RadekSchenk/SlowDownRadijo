import AVFoundation
import Combine
import MediaPlayer
import Network
import UIKit

enum PlaybackState: Equatable {
    case idle
    case connecting
    case playing
    case paused
    case error(String)
}

/// The two live mounts on play.cz, both over HTTPS. The `-fallback` mounts
/// next to them are Icecast's own backup sources, not for listeners.
enum LiveStream: String {
    /// MP3, 160 kbps, 44.1 kHz stereo (~72 MB an hour).
    case mp3
    /// HE-AAC, 32 kbps (~14 MB an hour).
    case aac

    var url: URL {
        switch self {
        case .mp3: return URL(string: "https://icecast9.play.cz/slowdown.mp3")!
        case .aac: return URL(string: "https://icecast5.play.cz/slowdown.aac")!
        }
    }

    var other: LiveStream { self == .mp3 ? .aac : .mp3 }
}

/// Settings ▸ Kvalita zvuku. `auto` plays the MP3 on a network that isn't
/// expensive (Wi-Fi, Ethernet) and the AAC on mobile data or a hotspot.
enum StreamQuality: String, CaseIterable, Identifiable {
    case auto, high, low

    static let storageKey = "streamQuality"

    static var current: StreamQuality {
        UserDefaults.standard.string(forKey: storageKey).flatMap(StreamQuality.init(rawValue:)) ?? .auto
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: return L10n.streamQualityAuto
        case .high: return L10n.streamQualityHigh
        case .low: return L10n.streamQualityLow
        }
    }

    func stream(onExpensiveNetwork expensive: Bool) -> LiveStream {
        switch self {
        case .auto: return expensive ? .aac : .mp3
        case .high: return .mp3
        case .low: return .aac
        }
    }
}

/// Owns the live audio stream: AVPlayer setup, background playback,
/// lock-screen / Control Center integration, and reconnect-on-drop logic.
///
/// Which stream plays follows `StreamQuality`; when one keeps failing,
/// reconnects alternate with the other one.
final class RadioPlayerService: NSObject, ObservableObject {
    /// The stream the song-on-air metadata is read from: the light AAC one,
    /// whatever plays.
    static let streamURL = LiveStream.aac.url

    @Published private(set) var state: PlaybackState = .idle
    /// The stream playing (or connecting) now; `nil` before the first play.
    private(set) var currentStream: LiveStream?
    /// Whether the current network is mobile data or a hotspot.
    private var networkIsExpensive = false

    /// What last started playback, and what last stopped it — read by
    /// `PlaybackAnalytics` when the state changes.
    enum PlayTrigger: String {
        case user, autoplay, lockScreen = "lock_screen", notification, resume, preview, carPlay = "carplay", alarm
    }

    enum StopReason: String {
        case user, sleepTimer = "sleep_timer", interruption, headphones, voiceMessage = "voice_message", preview
    }

    private(set) var lastPlayTrigger: PlayTrigger = .user
    private(set) var lastStopReason: StopReason = .user
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
    /// The radio alarm's gentle start (`rampVolume`): from 20 % up to full
    /// over `rampDuration`, also across reconnects.
    private var rampStart: Date?
    private var rampDuration: TimeInterval = 30
    private var rampTimer: Timer?

    /// What the lock screen, Control Center and CarPlay show — set by
    /// `NowPlayingViewModel`.
    private var nowPlayingTitle = "Slow Down Rádijo"
    private var nowPlayingSubtitle = "Slow Down Rádijo"
    private var currentArtwork: UIImage?

    /// Set when a call, Siri, an alarm or another app took the audio session
    /// away from live playback, so the stream resumes when it's handed back.
    private var wasPlayingBeforeInterruption = false

    /// Watches connectivity so a dropout reconnects as soon as the network
    /// is back. Starts as "satisfied" so the first report at launch isn't
    /// mistaken for a comeback.
    private let pathMonitor = NWPathMonitor()
    private var networkWasSatisfied = true

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            let isExpensive = path.isExpensive
            DispatchQueue.main.async {
                guard let self else { return }
                let cameBack = isSatisfied && !self.networkWasSatisfied
                self.networkWasSatisfied = isSatisfied
                let expensiveChanged = isSatisfied && isExpensive != self.networkIsExpensive
                if isSatisfied { self.networkIsExpensive = isExpensive }
                if cameBack {
                    self.networkBecameAvailable()
                } else if expensiveChanged {
                    self.restartIfStreamChanged()
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "cz.slowdownradijo.network-path"))
    }

    deinit {
        pathMonitor.cancel()
        teardownPlayer()
        reconnectTimer?.invalidate()
        connectTimeoutTimer?.invalidate()
        sleepTimer?.invalidate()
    }

    // MARK: - Public API

    func togglePlayPause(trigger: PlayTrigger = .user) {
        switch state {
        case .playing:
            pause()
        case .idle, .paused, .error:
            play(trigger: trigger)
        case .connecting:
            break
        }
    }

    func play(trigger: PlayTrigger = .user) {
        lastPlayTrigger = trigger
        wasPlayingBeforeInterruption = false
        cancelReconnect()
        reconnectAttempt = 0
        startPlayback()
    }

    func pause(reason: StopReason = .user) {
        lastStopReason = reason
        wasPlayingBeforeInterruption = false
        // A reconnect scheduled after a dropout must not restart the stream
        // the listener (or the sleep timer) just paused.
        cancelReconnect()
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        player?.pause()
        endVolumeRamp()
        state = .paused
        updateNowPlayingPlaybackRate(0)
    }

    // MARK: - Volume ramp (radio alarm)

    /// The radio alarm with the app running: the volume rises from 20 %
    /// to full over `seconds`. Pausing ends it.
    func rampVolume(over seconds: TimeInterval) {
        rampStart = Date()
        rampDuration = seconds
        player?.volume = rampVolume
        rampTimer?.invalidate()
        rampTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.player?.volume = self.rampVolume
            if self.rampVolume >= 1 { self.endVolumeRamp() }
        }
    }

    private var rampVolume: Float {
        guard let rampStart else { return 1 }
        return Float(min(1, 0.2 + 0.8 * Date().timeIntervalSince(rampStart) / rampDuration))
    }

    private func endVolumeRamp() {
        rampTimer?.invalidate()
        rampTimer = nil
        rampStart = nil
        player?.volume = 1
    }

    /// Called by the view model whenever the parsed now-playing metadata or
    /// current-show artwork changes, so lock screen / Control Center stay in sync.
    func updateNowPlaying(title: String, subtitle: String, artwork: UIImage?) {
        nowPlayingTitle = title
        nowPlayingSubtitle = subtitle
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
            pause(reason: .sleepTimer)
            sleepTimerFireDate = nil
            return
        }
        sleepTimerFireDate = fireDate
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause(reason: .sleepTimer)
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

    /// Called when Settings changes the quality: a playing radio moves to
    /// the newly chosen stream.
    func streamQualityChanged() {
        restartIfStreamChanged()
    }

    // MARK: - Stream choice

    /// The stream the setting and the network ask for.
    private var preferredStream: LiveStream {
        StreamQuality.current.stream(onExpensiveNetwork: networkIsExpensive)
    }

    /// The first reconnect retries the same stream (most drops are the
    /// network); from then on every even attempt tries the other one, in
    /// case only one of the two mounts is down.
    private var streamForThisAttempt: LiveStream {
        reconnectAttempt >= 2 && reconnectAttempt % 2 == 0 ? preferredStream.other : preferredStream
    }

    /// Wi-Fi ↔ mobile data or a new setting while the radio plays: switch to
    /// the stream that fits now (a short gap, like a reconnect).
    private func restartIfStreamChanged() {
        guard state == .playing || state == .connecting,
              let currentStream, currentStream != preferredStream else { return }
        cancelReconnect()
        reconnectAttempt = 0
        startPlayback()
    }

    // MARK: - Playback lifecycle

    private func startPlayback() {
        configureAudioSession(activate: true)
        enterConnecting()
        teardownPlayer()

        let stream = streamForThisAttempt
        currentStream = stream
        let item = AVPlayerItem(url: stream.url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.volume = rampVolume
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
                    // `pause()`, interruptions and failures set the state
                    // themselves. A stop nobody asked for (the connection
                    // dropped and the buffer ran dry) is handled like a
                    // stall: `.connecting`, then a reconnect on timeout.
                    if self.state == .playing {
                        self.enterConnecting()
                    }
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
                    // Ready isn't audible yet (still buffering): `.playing`
                    // comes from `timeControlStatus` once audio really runs.
                    self?.reconnectAttempt = 0
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

        // A live stream has no end: "played to the end" means the
        // connection closed and the buffered audio ran out.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemPlayedToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func itemPlayedToEndTime() {
        guard state == .playing || state == .connecting else { return }
        handleFailure()
    }

    /// Unplugging headphones (or a Bluetooth device going away) pauses
    /// AVPlayer; mirror it as a pause so playback doesn't resume through
    /// the speaker on its own.
    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.state == .playing || self.state == .connecting else { return }
            self.pause(reason: .headphones)
        }
    }

    /// The network came back while waiting out the back-off after a
    /// dropout (or stuck connecting): try again now instead of after up to
    /// 30 s.
    private func networkBecameAvailable() {
        switch state {
        case .error where reconnectTimer != nil, .connecting:
            cancelReconnect()
            startPlayback()
        default:
            break
        }
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
                self.pause(reason: .interruption)
                self.wasPlayingBeforeInterruption = true
            case .ended:
                guard self.wasPlayingBeforeInterruption else { return }
                self.wasPlayingBeforeInterruption = false
                if shouldResume {
                    self.play(trigger: .resume)
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
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        player?.pause()
        player = nil
        playerItem = nil
    }

    // MARK: - Audio session (background playback)

    private func configureAudioSession(activate: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            // Long-form audio, like Music and Podcasts: it shares their
            // output, so a speaker picked for them (or in the AirPlay
            // picker) is where the radio plays too.
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
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
            self?.play(trigger: .lockScreen)
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(trigger: .lockScreen)
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
        info[MPMediaItemPropertyTitle] = nowPlayingTitle
        info[MPMediaItemPropertyArtist] = nowPlayingSubtitle
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0

        // The show's photo, as on the home screen card.
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
