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

    private let radioPlayer: RadioPlayerService
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var wasRadioPlayingBeforePreview = false
    private var loadTask: Task<Void, Never>?

    init(radioPlayer: RadioPlayerService) {
        self.radioPlayer = radioPlayer
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
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

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        isLoading = false
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

    private func play(url: URL) {
        wasRadioPlayingBeforePreview = radioPlayer.state == .playing
        radioPlayer.pause()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        isLoading = false

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }

        newPlayer.play()
    }
}
