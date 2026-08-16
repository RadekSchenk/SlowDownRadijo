import Combine
import Foundation
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([HistoryTrack])
    }

    private static let pageSize = 20
    private static let windowInterval: TimeInterval = 24 * 60 * 60
    /// Safety-net only now that `PlayHistoryStore.recordedTrackPublisher`
    /// delivers new tracks the instant they're written — this just catches
    /// anything that publisher missed (there shouldn't be anything, but the
    /// cost of asking is negligible).
    private static let liveCheckInterval: TimeInterval = 20
    /// A remote (`played_tracks`) row within this many seconds of a local
    /// entry for the same artist+title counts as "the same play" rather
    /// than a second one — the two sources observe the same track change
    /// at slightly different moments (local is near-instant, the server
    /// only polls once a minute), not two separate plays. Empirically the
    /// gap can run close to 5 minutes (not just the ~1 minute the cron
    /// interval alone would suggest), so this is deliberately generous.
    private static let dedupeWindow: TimeInterval = 8 * 60

    @Published private(set) var state: State = .loading
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    /// The `HistoryTrack.id` that just arrived via
    /// `recordedTrackPublisher`, if any — `HomeView` uses this to briefly
    /// highlight that row so it visibly reads as "just fell from Now
    /// Playing" rather than silently appearing. Cleared a moment later.
    @Published private(set) var justInsertedTrackID: UUID?

    private let historyStore: PlayHistoryStore
    /// Tracks this device actually observed itself, from local
    /// `PlayHistoryStore` — paginated, plus live inserts.
    private var localTracks: [HistoryTrack] = []
    /// Backfill from the server's `played_tracks` table — paginated the
    /// same way as `localTracks`, one page fetched per `loadNextPage()`
    /// call, so opening "Co hrálo" doesn't eagerly pull the whole 24h
    /// window over the network. Covers stretches where the app wasn't open
    /// to observe anything locally; filtered against `localTracks` at merge
    /// time so a track both sources saw only shows once (see `publish()`).
    private var remoteTracks: [HistoryTrack] = []
    /// The last computed `localTracks` + `remoteTracks` merge — what
    /// `loadMoreIfNeeded` scans, since that's what's actually on screen.
    private var displayedTracks: [HistoryTrack] = []
    /// Local pagination cursor: fetch everything strictly older than this
    /// next. `nil` remote counterpart is `remoteCursor` below.
    private var oldestLoaded: Date = .distantFuture
    /// Remote pagination cursor — `nil` means "fetch from the top", same
    /// convention `RemoteHistoryService.fetchPage` expects.
    private var remoteCursor: Date?
    private var localHasMore = true
    private var remoteHasMore = true
    /// Live-update cursor: fetch everything strictly newer than this to
    /// prepend, without disturbing pagination further down the list.
    private var newestLoaded: Date = .distantPast
    private var windowStart = Date()
    private var liveCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var highlightClearTask: Task<Void, Never>?
    private var pageLoadTask: Task<Void, Never>?

    init(historyStore: PlayHistoryStore) {
        self.historyStore = historyStore
        liveCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.liveCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForNewEntries()
            }
        }

        historyStore.recordedTrackPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] record in
                self?.handleRecorded(record)
            }
            .store(in: &cancellables)

        historyStore.artworkUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleArtworkUpdate(id: update.id, url: update.url)
            }
            .store(in: &cancellables)

        historyStore.noITunesMatchPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.handleNoITunesMatch(id: id)
            }
            .store(in: &cancellables)
    }

    deinit {
        liveCheckTimer?.invalidate()
        highlightClearTask?.cancel()
        pageLoadTask?.cancel()
    }

    func loadIfNeeded() {
        guard case .loading = state else { return }
        refresh()
    }

    func refresh() {
        pageLoadTask?.cancel()
        localTracks = []
        remoteTracks = []
        oldestLoaded = .distantFuture
        remoteCursor = nil
        newestLoaded = .distantPast
        localHasMore = true
        remoteHasMore = true
        hasMore = true
        windowStart = Date().addingTimeInterval(-Self.windowInterval)

        pageLoadTask = Task { [weak self] in
            await self?.loadNextPage()
        }
    }

    /// Call when a row appears on screen; triggers the next page once the
    /// user scrolls near the end of what's currently loaded.
    func loadMoreIfNeeded(current track: HistoryTrack) {
        guard hasMore, !isLoadingMore else { return }
        guard let index = displayedTracks.firstIndex(where: { $0.id == track.id }) else { return }
        let thresholdIndex = displayedTracks.index(displayedTracks.endIndex, offsetBy: -5, limitedBy: displayedTracks.startIndex) ?? displayedTracks.startIndex
        guard index >= thresholdIndex else { return }

        isLoadingMore = true
        pageLoadTask?.cancel()
        pageLoadTask = Task { [weak self] in
            await self?.loadNextPage()
            self?.isLoadingMore = false
        }
    }

    /// Fetches the next page from both sources — local is a fast
    /// synchronous SwiftData read, so it publishes immediately; the remote
    /// page (network) merges in a moment later once it resolves. Best
    /// effort on the remote side: silently leaves `remoteHasMore` as-is on
    /// failure (offline, server hiccup) so the next scroll trigger just
    /// retries, since "Co hrálo" already works fine from local data alone.
    private func loadNextPage() async {
        let localPage = historyStore.fetchPage(before: oldestLoaded, windowStart: windowStart, limit: Self.pageSize)
        appendLocal(localPage)
        hasMore = localHasMore || remoteHasMore
        publish()

        guard remoteHasMore,
              let remotePage = try? await RemoteHistoryService.fetchPage(before: remoteCursor, windowStart: windowStart, limit: Self.pageSize),
              !Task.isCancelled else { return }
        appendRemote(remotePage)
        hasMore = localHasMore || remoteHasMore
        publish()
        resolveArtworkForRemoteTracks()
    }

    /// The `played_tracks` table doesn't store artwork (see
    /// `RemotePlayedTrack`) — every server-filled row starts with none, so
    /// look each one up lazily via the same iTunes search used for local
    /// entries and patch it in once resolved.
    ///
    /// Deliberately sequential, not one `Task` per track: a fresh page can
    /// have up to 20 rows missing artwork at once, and firing that many
    /// concurrent lookups at Apple's iTunes Search API risks tripping its
    /// rate limiting, which previously left several tracks (whichever lost
    /// the race) permanently stuck with neither artwork nor a working
    /// preview button.
    private func resolveArtworkForRemoteTracks() {
        let pending = remoteTracks.filter { $0.artworkURL == nil && !$0.hasNoITunesMatch }
        guard !pending.isEmpty else { return }

        Task { [weak self] in
            for track in pending {
                guard let self else { return }
                let id = track.id
                guard let index = self.remoteTracks.firstIndex(where: { $0.id == id }) else { continue }
                guard let url = await ITunesArtworkService.shared.artworkURL(artist: track.artist, title: track.title) else {
                    guard !self.remoteTracks[index].hasNoITunesMatch else { continue }
                    self.remoteTracks[index].hasNoITunesMatch = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        self.publish()
                    }
                    continue
                }
                guard self.remoteTracks[index].artworkURL == nil else { continue }
                self.remoteTracks[index].artworkURL = url
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.publish()
                }
            }
        }
    }

    /// Inserts a track the instant it's recorded — see
    /// `PlayHistoryStore.recordedTrackPublisher`. This is what actually
    /// fixes the latency; `checkForNewEntries` below just double-checks
    /// nothing was missed.
    private func handleRecorded(_ record: PlayedTrackRecord) {
        guard case .loaded = state else { return }
        guard record.playedAt > newestLoaded else { return }

        newestLoaded = record.playedAt
        let track = HistoryTrack(record)
        localTracks.insert(track, at: 0)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            publish()
            justInsertedTrackID = track.id
        }

        highlightClearTask?.cancel()
        highlightClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) {
                self?.justInsertedTrackID = nil
            }
        }
    }

    /// Patches in artwork that resolved after the row was already inserted
    /// — otherwise a track that fell into "Co hrálo" before its iTunes
    /// lookup finished would be stuck without artwork forever.
    private func handleArtworkUpdate(id: UUID, url: URL) {
        guard let index = localTracks.firstIndex(where: { $0.id == id }) else { return }
        guard localTracks[index].artworkURL != url else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            localTracks[index].artworkURL = url
            publish()
        }
    }

    /// A confirmed iTunes non-match — hides the action pills for this row
    /// (see `HistoryTrack.hasNoITunesMatch`).
    private func handleNoITunesMatch(id: UUID) {
        guard let index = localTracks.firstIndex(where: { $0.id == id }) else { return }
        guard !localTracks[index].hasNoITunesMatch else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            localTracks[index].hasNoITunesMatch = true
            publish()
        }
    }

    private func checkForNewEntries() {
        guard case .loaded = state else { return }
        let fresh = historyStore.fetchPage(before: .distantFuture, windowStart: newestLoaded, limit: 50)
            .filter { $0.playedAt > newestLoaded }
        guard !fresh.isEmpty else { return }

        newestLoaded = fresh.map(\.playedAt).max() ?? newestLoaded
        localTracks.insert(contentsOf: fresh.map(HistoryTrack.init), at: 0)
        // Animated so a track that just fell off "now playing" visibly
        // slides into the top of the list instead of popping in.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            publish()
        }
    }

    private func appendLocal(_ page: [PlayedTrackRecord]) {
        guard !page.isEmpty else {
            localHasMore = false
            return
        }
        oldestLoaded = page.map(\.playedAt).min() ?? oldestLoaded
        newestLoaded = max(newestLoaded, page.map(\.playedAt).max() ?? newestLoaded)
        localTracks.append(contentsOf: page.map(HistoryTrack.init))
        if page.count < Self.pageSize {
            localHasMore = false
        }
    }

    private func appendRemote(_ page: [RemotePlayedTrack]) {
        guard !page.isEmpty else {
            remoteHasMore = false
            return
        }
        remoteCursor = page.map(\.playedAt).min() ?? remoteCursor
        remoteTracks.append(contentsOf: page.map(HistoryTrack.init))
        if page.count < Self.pageSize {
            remoteHasMore = false
        }
    }

    /// Recomputes the merged local+remote list and publishes it. Re-runs
    /// the dedupe against *all* currently-known local tracks every time
    /// (not just once) — cheap at this scale, and correct even if a local
    /// page loads later and turns out to cover a stretch a remote entry
    /// had already filled in.
    private func publish() {
        let filteredRemote = remoteTracks.filter { remote in
            !localTracks.contains { isDuplicate($0, remote) }
        }
        displayedTracks = (localTracks + filteredRemote)
            .sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
        state = .loaded(displayedTracks)
    }

    private func isDuplicate(_ a: HistoryTrack, _ b: HistoryTrack) -> Bool {
        guard a.artist.caseInsensitiveCompare(b.artist) == .orderedSame,
              a.title.caseInsensitiveCompare(b.title) == .orderedSame,
              let dateA = a.playedAt, let dateB = b.playedAt else { return false }
        return abs(dateA.timeIntervalSince(dateB)) < Self.dedupeWindow
    }
}

private extension HistoryTrack {
    init(_ record: PlayedTrackRecord) {
        self.init(
            id: record.id,
            artist: record.artist,
            title: record.title,
            album: nil,
            artworkURL: record.artworkURL ?? record.showImageURL,
            hasNoITunesMatch: record.hasNoITunesMatch,
            playedAt: record.playedAt,
            show: record.showName.map { name in
                Show(id: name, name: name, start: "", end: "", imageURL: record.showImageURL)
            }
        )
    }

    init(_ remote: RemotePlayedTrack) {
        self.init(
            id: remote.id,
            artist: remote.artist,
            title: remote.title,
            album: nil,
            artworkURL: nil,
            hasNoITunesMatch: false,
            playedAt: remote.playedAt,
            show: remote.showName.map { name in
                Show(id: name, name: name, start: "", end: "", imageURL: nil)
            }
        )
    }
}
