import Foundation

/// Shared by `HistoryTrack` and `NowPlayingTrack` — a best-effort Spotify
/// search deep link (see `HistoryTrack.spotifySearchURL` for why it's a
/// search rather than a guaranteed exact-track link).
func spotifySearchURL(artist: String, title: String) -> URL? {
    let query = "\(artist) \(title)".trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty,
          let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
        return nil
    }
    return URL(string: "https://open.spotify.com/search/\(encoded)")
}
