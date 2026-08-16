import Combine
import Foundation
import SwiftData

/// Local, on-device log of everything `ICYMetadataService` has observed
/// playing. This is the sole source for "Co hrálo" — see
/// `PlayedTrackRecord` for why we stopped relying on the station's own
/// website history.
@MainActor
final class PlayHistoryStore {
    /// We keep a bit more than the 24h the UI shows, as a buffer.
    private static let retention: TimeInterval = 3 * 24 * 60 * 60

    /// Fires the instant a track is written — lets `HistoryViewModel` insert
    /// it into "Co hrálo" the moment it happens, instead of waiting for its
    /// own polling timer to notice (which was the source of the 20s+
    /// latency between a track finishing and it showing up in history).
    let recordedTrackPublisher = PassthroughSubject<PlayedTrackRecord, Never>()

    /// Fires when a track's artwork resolves *after* it was already
    /// recorded (and likely already displayed) — the iTunes lookup in
    /// `NowPlayingViewModel` is async and often finishes after the instant
    /// insert above, so without this the row would be stuck showing
    /// whatever fallback image it had at insert time forever.
    let artworkUpdatedPublisher = PassthroughSubject<(id: UUID, url: URL), Never>()

    /// Fires once a track's iTunes lookup has definitively come back with
    /// no match — see `HistoryTrack.hasNoITunesMatch`.
    let noITunesMatchPublisher = PassthroughSubject<UUID, Never>()

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() {
        do {
            // Explicit, distinct file — see `FavoriteTrackStore` for why:
            // `ModelContainer(for:)` without one defaults every SwiftData
            // container in the app to the same `default.store` file no
            // matter which type is passed in.
            let url = URL.applicationSupportDirectory.appending(path: "PlayHistory.sqlite")
            let configuration = ModelConfiguration(url: url)
            container = try ModelContainer(for: PlayedTrackRecord.self, configurations: configuration)
        } catch {
            fatalError("Failed to create PlayHistoryStore container: \(error)")
        }
        pruneOld()
    }

    /// Records a newly-observed track. Callers are expected to have already
    /// deduped against the currently-playing track (see
    /// `NowPlayingViewModel`) — this doesn't re-check for consecutive
    /// duplicates itself.
    @discardableResult
    func record(artist: String, title: String, playedAt: Date, showName: String?, showImageURL: URL?) -> PlayedTrackRecord {
        let record = PlayedTrackRecord(
            artist: artist,
            title: title,
            playedAt: playedAt,
            showName: showName,
            showImageURL: showImageURL
        )
        context.insert(record)
        try? context.save()
        recordedTrackPublisher.send(record)
        return record
    }

    func updateArtwork(for id: UUID, to url: URL) {
        let descriptor = FetchDescriptor<PlayedTrackRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.artworkURLString = url.absoluteString
        try? context.save()
        artworkUpdatedPublisher.send((id: id, url: url))
    }

    func markNoITunesMatch(for id: UUID) {
        let descriptor = FetchDescriptor<PlayedTrackRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(descriptor).first else { return }
        // A later-arriving artwork update (or a repeat call) shouldn't
        // clobber a real match or re-fire the publisher pointlessly.
        guard record.artworkURLString == nil, !record.hasNoITunesMatch else { return }
        record.hasNoITunesMatch = true
        try? context.save()
        noITunesMatchPublisher.send(id)
    }

    /// Fetches up to `limit` records strictly older than `cursor`, no older
    /// than `windowStart`, newest first. Passing `Date.distantFuture` as the
    /// cursor fetches from the very top.
    func fetchPage(before cursor: Date, windowStart: Date, limit: Int) -> [PlayedTrackRecord] {
        var descriptor = FetchDescriptor<PlayedTrackRecord>(
            predicate: #Predicate { $0.playedAt < cursor && $0.playedAt >= windowStart },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func pruneOld() {
        let cutoff = Date().addingTimeInterval(-Self.retention)
        let descriptor = FetchDescriptor<PlayedTrackRecord>(predicate: #Predicate { $0.playedAt < cutoff })
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        stale.forEach { context.delete($0) }
        try? context.save()
    }
}
