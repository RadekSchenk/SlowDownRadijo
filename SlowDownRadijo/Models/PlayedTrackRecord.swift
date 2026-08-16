import Foundation
import SwiftData

/// A track our own `ICYMetadataService` observed playing, persisted locally.
///
/// This is the app's own play log — built entirely from live stream
/// metadata, independent of slowdownradijo.cz's backend (whose own
/// "co hrálo" history turned out to be months stale; see git history / the
/// old `HistoryService` for that investigation). It starts empty on first
/// install and fills in as the station actually plays while the app is
/// running (foreground or backgrounded-with-audio).
@Model
final class PlayedTrackRecord {
    var id: UUID
    var artist: String
    var title: String
    var playedAt: Date
    var showName: String?
    var showImageURLString: String?
    /// Resolved lazily after insert via `ITunesArtworkService`; nil until
    /// (if ever) a match is found.
    var artworkURLString: String?
    /// Set once the iTunes lookup has definitively come back with nothing
    /// — see `HistoryTrack.hasNoITunesMatch` for what this gates in the UI.
    var hasNoITunesMatch: Bool = false

    init(
        artist: String,
        title: String,
        playedAt: Date,
        showName: String?,
        showImageURL: URL?,
        artworkURL: URL? = nil
    ) {
        self.id = UUID()
        self.artist = artist
        self.title = title
        self.playedAt = playedAt
        self.showName = showName
        self.showImageURLString = showImageURL?.absoluteString
        self.artworkURLString = artworkURL?.absoluteString
    }

    var showImageURL: URL? {
        showImageURLString.flatMap(URL.init(string:))
    }

    var artworkURL: URL? {
        artworkURLString.flatMap(URL.init(string:))
    }
}
