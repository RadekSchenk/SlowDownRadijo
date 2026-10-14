import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var track: NowPlayingTrack?
    /// When we first observed `track`'s current title via ICY metadata. Not
    /// an authoritative "track started" timestamp (the stream doesn't send
    /// one) — it's the moment our poller first saw this title, so it can lag
    /// the real start by up to the poll interval (20s). Shown so the "now
    /// playing" card lines up with the timestamps in "Co hrálo" below it.
    @Published private(set) var trackStartedAt: Date?
    /// The current track's own artwork, resolved via the public iTunes
    /// Search API. `nil` until resolved (or if no match is found — e.g. a
    /// DJ mix block that isn't a real "song"), in which case the UI should
    /// fall back to `currentShow`'s artwork.
    @Published private(set) var trackArtworkURL: URL?
    /// True once the iTunes lookup for the *current* track has come back
    /// with nothing (a jingle, station ID, DJ mix block — not a real
    /// catalogable song). Mirrors `HistoryTrack.hasNoITunesMatch`; gates
    /// the "Nyní" row's preview badge the same way (see `HomeView`) —
    /// there's genuinely no clip to play, so the button shouldn't show.
    @Published private(set) var currentTrackHasNoITunesMatch = false
    @Published private(set) var currentShow: Show?
    /// `track`, but only while `TrackTrust` is sure it's a real song playing
    /// right now — what the home screen shows under the host.
    @Published private(set) var verifiedTrack: NowPlayingTrack?
    @Published private(set) var showArtwork: UIImage?
    /// Fraction (0...1) of `currentShow`'s scheduled block elapsed right now.
    @Published private(set) var showProgress: Double = 0
    @Published private(set) var showRemainingMinutes: Int = 0

    let player: RadioPlayerService
    private let metadataService: ICYMetadataService
    private let scheduleStore: ScheduleStore
    private let historyStore: PlayHistoryStore

    private var cancellables = Set<AnyCancellable>()
    private var showRefreshTimer: Timer?
    private var showArtworkTask: Task<Void, Never>?
    private var trackArtworkTask: Task<Void, Never>?
    /// Downloaded bytes for `trackArtworkURL`, used for MPNowPlayingInfoCenter
    /// (which needs actual image data, not a URL).
    private var trackArtworkImage: UIImage?
    /// When the current `track` really started, if we know: we saw the
    /// metadata change to it, or the server logged its start. `nil` right
    /// after launch until one of those confirms it.
    private var trackConfirmedStart: Date?
    private var lastServerCheck = Date.distantPast
    private var serverCheckTask: Task<Void, Never>?
    private lazy var allShows: [Show] = scheduleStore.days.flatMap(\.shows)
    private var playbackAnalytics: PlaybackAnalytics?

    init(
        player: RadioPlayerService,
        metadataService: ICYMetadataService,
        scheduleStore: ScheduleStore,
        historyStore: PlayHistoryStore
    ) {
        self.player = player
        self.metadataService = metadataService
        self.scheduleStore = scheduleStore
        self.historyStore = historyStore

        // Listening stats: credit playback time to whichever show is airing
        // at each tick. Every way of playing goes through `player.state`, so
        // this one hook covers the lock screen, headphones and CarPlay too.
        ListeningTracker.shared.configure { [weak scheduleStore] in
            scheduleStore?.currentShow()?.id
        }

        playbackAnalytics = PlaybackAnalytics(player: player) { [weak scheduleStore] in
            scheduleStore?.currentShow()?.id
        }

        player.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.playbackState = state
                ListeningTracker.shared.update(isPlaying: state == .playing)
            }
            .store(in: &cancellables)

        // The lock screen's "Hosted by" follows the app's language.
        LocalizationManager.shared.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.publishNowPlaying() }
            .store(in: &cancellables)

        metadataService.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTrack in
                self?.handleTrackChange(newTrack)
            }
            .store(in: &cancellables)

        updateShowState()
        // Ticks every 20s so the progress bar advances smoothly rather than
        // jumping once a minute; recomputing the schedule lookup is cheap.
        showRefreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateShowState()
                self?.updateVerifiedTrack()
            }
        }

        metadataService.start()
    }

    deinit {
        showRefreshTimer?.invalidate()
        showArtworkTask?.cancel()
        trackArtworkTask?.cancel()
        serverCheckTask?.cancel()
    }

    var displayTitle: String {
        track?.displayText ?? currentShow?.localizedName ?? "Slow Down Rádijo"
    }

    var showName: String {
        currentShow?.localizedName ?? "Slow Down Rádijo"
    }

    /// For the sleep timer's "Konec pořadu" option.
    var currentShowEndDate: Date? {
        guard let currentShow else { return nil }
        return scheduleStore.endDate(for: currentShow)
    }

    func togglePlayPause() {
        player.togglePlayPause()
    }

    /// A track is only written to the local play log once we see it get
    /// replaced by the next one — at that point we know it actually played
    /// for a real stretch, not just flickered past in one poll. This also
    /// avoids showing the exact same track twice: once as "now playing" and
    /// again as the newest "Co hrálo" row.
    private func handleTrackChange(_ newTrack: NowPlayingTrack?) {
        guard newTrack != track else { return }

        // A change we watched happen dates the new title; the first title
        // after launch could have been there for an hour, so it waits for
        // the server's log to say when it started.
        trackConfirmedStart = (track != nil && newTrack != nil) ? Date() : nil
        serverCheckTask?.cancel()
        lastServerCheck = .distantPast

        if let endedTrack = track, let startedAt = trackStartedAt,
           !endedTrack.artist.isEmpty, !endedTrack.title.isEmpty {
            let show = scheduleStore.show(at: startedAt)
            let record = historyStore.record(
                artist: endedTrack.artist,
                title: endedTrack.title,
                playedAt: startedAt,
                showName: show?.name,
                showImageURL: show?.imageURL
            )
            Task {
                if let artworkURL = await ITunesArtworkService.shared.artworkURL(
                    artist: endedTrack.artist,
                    title: endedTrack.title
                ) {
                    await MainActor.run {
                        self.historyStore.updateArtwork(for: record.id, to: artworkURL)
                    }
                } else {
                    await MainActor.run {
                        self.historyStore.markNoITunesMatch(for: record.id)
                    }
                }
            }
        }

        trackStartedAt = Date()
        // Animated so the now-playing row crossfades to the new track
        // instead of snapping instantly — paired with `.contentTransition`
        // on the artwork/text in `TrackDetailsRow`.
        withAnimation(.easeInOut(duration: 0.35)) {
            track = newTrack
        }
        loadTrackArtwork(for: newTrack)
        publishNowPlaying()
        updateVerifiedTrack()
    }

    /// Re-run on every track change and every 20s, so a title that gets
    /// stuck disappears once it's older than `TrackTrust.maximumAge`.
    private func updateVerifiedTrack() {
        #if DEBUG
        // Screenshot tests: `-debugVerifiedTrack "Artist - Title"` shows a
        // song line without waiting for one on the live stream.
        if let forced = UserDefaults.standard.string(forKey: "debugVerifiedTrack") {
            verifiedTrack = NowPlayingTrack.parse(streamTitle: forced)
            return
        }
        #endif
        let now = Date()
        var trusted: NowPlayingTrack?
        if let track, TrackTrust.isRealSong(track, shows: allShows) {
            if let start = trackConfirmedStart {
                let showStart = currentShow?.hostName == nil
                    ? nil
                    : currentShow.flatMap { scheduleStore.startDate(for: $0, relativeTo: now) }
                if TrackTrust.isCurrent(start: start, now: now, showStart: showStart) {
                    trusted = track
                }
            } else if now.timeIntervalSince(lastServerCheck) >= 60 {
                checkServerStart(for: track)
            }
        }
        guard trusted != verifiedTrack else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            verifiedTrack = trusted
        }
        publishNowPlaying()
    }

    /// Asks `played_tracks` (logged every minute by `collect-now-playing`)
    /// when the current title started. Retried each minute until it shows
    /// up there.
    private func checkServerStart(for track: NowPlayingTrack) {
        lastServerCheck = Date()
        serverCheckTask?.cancel()
        serverCheckTask = Task { [weak self] in
            guard let rows = try? await RemoteHistoryService.fetchPage(
                before: nil,
                windowStart: Date().addingTimeInterval(-3 * 3600),
                limit: 1
            ), let latest = rows.first, !Task.isCancelled else { return }
            guard let self, self.track == track,
                  TrackTrust.matches(track, artist: latest.artist, title: latest.title) else { return }
            self.trackConfirmedStart = latest.playedAt
            self.updateVerifiedTrack()
        }
    }

    private func loadTrackArtwork(for track: NowPlayingTrack?) {
        trackArtworkTask?.cancel()
        trackArtworkURL = nil
        trackArtworkImage = nil
        currentTrackHasNoITunesMatch = false

        guard let track, !track.artist.isEmpty, !track.title.isEmpty else { return }

        trackArtworkTask = Task { [weak self] in
            guard let url = await ITunesArtworkService.shared.artworkURL(artist: track.artist, title: track.title) else {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.currentTrackHasNoITunesMatch = true }
                return
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self?.trackArtworkURL = url
                }
            }

            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  !Task.isCancelled,
                  let image = UIImage(data: data) else { return }

            await MainActor.run {
                self?.trackArtworkImage = image
                self?.publishNowPlaying()
            }
        }
    }

    private func updateShowState() {
        let now = Date()
        let show = scheduleStore.currentShow(at: now)
        if show != currentShow {
            currentShow = show
            loadShowArtwork(for: show)
        }

        if let show {
            showProgress = scheduleStore.progress(for: show, at: now)
            showRemainingMinutes = scheduleStore.remainingMinutes(for: show, at: now)
        } else {
            showProgress = 0
            showRemainingMinutes = 0
        }
    }

    private func loadShowArtwork(for show: Show?) {
        showArtworkTask?.cancel()
        // A bundled photo is there at once, no download.
        if let name = show?.artworkName, let image = UIImage(named: name) {
            showArtwork = image
            publishNowPlaying()
            return
        }
        guard let url = show?.imageURL else {
            showArtwork = nil
            publishNowPlaying()
            return
        }
        showArtworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.showArtwork = image
                self?.publishNowPlaying()
            }
        }
    }

    /// The lock screen, Control Center and CarPlay show what the home
    /// screen shows: the song only when `TrackTrust` vouches for it (never
    /// the raw stream title — promos, show placeholders, stuck songs), with
    /// the show below; otherwise the show and its host. Always the show's
    /// own photo, as on the home card.
    private func publishNowPlaying() {
        let showTitle = currentShow?.displayTitle ?? "Slow Down Rádijo"
        let title: String
        let subtitle: String
        if let song = verifiedTrack {
            title = "\(song.artist) – \(song.title)"
            subtitle = showTitle
        } else {
            title = showTitle
            subtitle = currentShow?.hostName.map { "\(L10n.hostedByKicker) \($0)" } ?? "Slow Down Rádijo"
        }
        player.updateNowPlaying(title: title, subtitle: subtitle, artwork: showArtwork)
    }
}
