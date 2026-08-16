import Foundation

/// A single entry in "Co hrálo" — a track our own `ICYMetadataService`
/// observed playing, read back from the local `PlayHistoryStore`.
struct HistoryTrack: Identifiable, Equatable {
    let id: UUID
    let artist: String
    let title: String
    let album: String?
    /// Mutable: a track's artwork can arrive *after* it's already been
    /// recorded and shown (the iTunes lookup is async) — see
    /// `PlayHistoryStore.artworkUpdatedPublisher`.
    var artworkURL: URL?
    /// True once the iTunes lookup has come back with nothing — not just
    /// "no artwork found yet" (that's `artworkURL == nil` while this is
    /// still `false`). Rows for a confirmed non-match hide their action
    /// pills entirely (see `TrackDetailsRow`): if it's not a real
    /// catalogable song (a jingle, station ID, DJ mix block), a preview
    /// can't work, and favoriting/Spotify-searching it doesn't make sense
    /// either.
    var hasNoITunesMatch: Bool = false
    let playedAt: Date?

    /// The show that was airing when this track played, if known.
    var show: Show?

    /// Opens Spotify's search results for this track. We don't have a
    /// direct track URI, so this is a best-effort search deep link rather
    /// than an exact-track link — Spotify almost always ranks the right
    /// track first, but it's not guaranteed. Getting a guaranteed
    /// exact-track link would require Spotify's Web API with app
    /// credentials, which this project intentionally doesn't depend on.
    var spotifySearchURL: URL? {
        SlowDownRadijo.spotifySearchURL(artist: artist, title: title)
    }
}
