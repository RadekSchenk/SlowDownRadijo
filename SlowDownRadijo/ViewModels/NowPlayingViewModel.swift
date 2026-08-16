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
    @Published private(set) var currentShow: Show?
    @Published private(set) var showArtwork: UIImage?
    /// Fraction (0...1) of `currentShow`'s scheduled block elapsed right now.
    @Published private(set) var showProgress: Double = 0
    @Published private(set) var showRemainingMinutes: Int = 0
    /// What airs right after `currentShow`, so the progress bar can say
    /// what's coming up next.
    @Published private(set) var nextShow: Show?

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

        player.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.playbackState = state
            }
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
            }
        }

        metadataService.start()
    }

    deinit {
        showRefreshTimer?.invalidate()
        showArtworkTask?.cancel()
        trackArtworkTask?.cancel()
    }

    var displayTitle: String {
        track?.displayText ?? currentShow?.name ?? "Slow Down Rádijo"
    }

    var showName: String {
        currentShow?.name ?? "Slow Down Rádijo"
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
    }

    private func loadTrackArtwork(for track: NowPlayingTrack?) {
        trackArtworkTask?.cancel()
        trackArtworkURL = nil
        trackArtworkImage = nil

        guard let track, !track.artist.isEmpty, !track.title.isEmpty else { return }

        trackArtworkTask = Task { [weak self] in
            guard let url = await ITunesArtworkService.shared.artworkURL(artist: track.artist, title: track.title),
                  !Task.isCancelled else { return }

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
            nextShow = scheduleStore.nextShow(after: show, from: now)
        } else {
            showProgress = 0
            showRemainingMinutes = 0
            nextShow = nil
        }
    }

    private func loadShowArtwork(for show: Show?) {
        showArtworkTask?.cancel()
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

    private func publishNowPlaying() {
        // Prefer the track's own artwork; fall back to the show's, since a
        // live stream doesn't always resolve to a real per-track match
        // (e.g. DJ mix blocks).
        player.updateNowPlaying(track: track, showTitle: showName, artwork: trackArtworkImage ?? showArtwork)
    }
}
