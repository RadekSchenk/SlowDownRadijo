import AVFoundation
import Foundation

/// Plays a short iTunes preview clip when the user taps the play button on
/// a "Co hrálo"/Favorites row (see `TrackDetailsRow`) — one clip at a time,
/// ducking the live radio stream for its ~30s and handing control back
/// afterward. Shared app-wide via environment rather than per-row, since
/// only one preview should ever play at once.
@MainActor
final class PreviewPlayerService: ObservableObject {
    /// The normalized `artist|title` key of the track currently loading or
    /// playing a preview, if any — rows compare this against their own key
    /// (see `FavoriteTrack.normalize`) to render a loading/playing state
    /// instead of a plain play icon.
    @Published private(set) var activeKey: String?
    @Published private(set) var isLoading = false
    /// Fraction (0...1) through the currently-playing clip — drives the
    /// progress ring `TrackDetailsRow` draws around the preview badge.
    /// Meaningless (stays 0) outside `.playing`.
    @Published private(set) var progress: Double = 0

    private let radioPlayer: RadioPlayerService
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var wasRadioPlayingBeforePreview = false
    private var loadTask: Task<Void, Never>?

    init(radioPlayer: RadioPlayerService) {
        self.radioPlayer = radioPlayer
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
    }

    /// Tapping the row that's already active stops it (and resumes the
    /// radio, if it was playing); tapping any other row switches to that
    /// one instead.
    func toggle(artist: String, title: String) {
        let key = FavoriteTrack.normalize(artist: artist, title: title)
        guard activeKey != key else {
            stop()
            return
        }
        start(artist: artist, title: title, key: key)
    }

    /// Also called when a preview clip finishes on its own (see the
    /// `.AVPlayerItemDidPlayToEndTime` observer in `play(url:)`) — either
    /// way, the live stream resumes automatically if it was playing before
    /// the preview started.
    func stop() {
        loadTask?.cancel()
        loadTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        isLoading = false
        progress = 0
        guard activeKey != nil else { return }
        activeKey = nil
        if wasRadioPlayingBeforePreview {
            wasRadioPlayingBeforePreview = false
            radioPlayer.play()
        }
    }

    private func start(artist: String, title: String, key: String) {
        stop()
        activeKey = key
        isLoading = true

        loadTask = Task { [weak self] in
            guard let self else { return }
            let url = await ITunesArtworkService.shared.previewURL(artist: artist, title: title)
            guard !Task.isCancelled, self.activeKey == key else { return }
            guard let url else {
                self.isLoading = false
                self.activeKey = nil
                return
            }
            self.play(url: url)
        }
    }

    /// Ducks the live stream for the duration of the clip — pausing it here
    /// (rather than something lower-level like an audio-session mix) so
    /// `NowPlayingViewModel`'s `playbackState` reflects reality and the
    /// play button on the home screen visibly shows paused while a preview
    /// plays. `stop()` (called both on manual toggle-off and on natural
    /// end-of-clip below) hands control back automatically.
    private func play(url: URL) {
        wasRadioPlayingBeforePreview = radioPlayer.state == .playing
        radioPlayer.pause()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        isLoading = false
        progress = 0

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }

        // Drives the progress ring — 10 times a second is smooth enough for
        // a thin stroke without redrawing more than it needs to.
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let duration = self.player?.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            self.progress = min(max(time.seconds / duration, 0), 1)
        }

        newPlayer.play()
    }
}
