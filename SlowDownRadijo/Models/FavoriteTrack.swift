import Foundation
import SwiftData

/// A track the user saved via the heart button on a "Co hrálo"/Favorites
/// row. Local-only (no accounts exist in this app) — see
/// `FavoriteTrackStore`.
@Model
final class FavoriteTrack {
    var id: UUID
    var artist: String
    var title: String
    var artworkURLString: String?
    var addedAt: Date
    /// Case-insensitive "artist|title" — the same identity `HistoryViewModel`
    /// already uses to dedupe plays of the same song, reused here since
    /// there's no stable per-song ID anywhere in this app's data (see
    /// `RemotePlayedTrack`).
    var normalizedKey: String

    init(artist: String, title: String, artworkURL: URL?, addedAt: Date = Date()) {
        self.id = UUID()
        self.artist = artist
        self.title = title
        self.artworkURLString = artworkURL?.absoluteString
        self.addedAt = addedAt
        self.normalizedKey = Self.normalize(artist: artist, title: title)
    }

    var artworkURL: URL? {
        artworkURLString.flatMap(URL.init(string:))
    }

    static func normalize(artist: String, title: String) -> String {
        "\(artist)|\(title)".lowercased()
    }
}
