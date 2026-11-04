import Foundation

/// Parsed from the live ICY `StreamTitle` metadata embedded in the audio stream.
/// The station's convention is "STATION - ARTIST - TITLE" or "ARTIST - TITLE".
struct NowPlayingTrack: Equatable {
    let artist: String
    let title: String

    var displayText: String {
        if artist.isEmpty { return title }
        if title.isEmpty { return artist }
        return "\(artist) — \(title)"
    }

    var spotifySearchURL: URL? {
        SlowDownRadijo.spotifySearchURL(artist: artist, title: title)
    }

    /// Parses a raw ICY StreamTitle value into artist/title components.
    static func parse(streamTitle raw: String) -> NowPlayingTrack? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var parts = trimmed.components(separatedBy: " - ").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        // The station prefixes the station name ("SLOWDOWN") on every title; drop it.
        if parts.count > 2, parts[0].caseInsensitiveCompare("SLOWDOWN") == .orderedSame {
            parts.removeFirst()
        }

        if parts.count >= 2 {
            let artist = parts[0]
            let title = parts.dropFirst().joined(separator: " - ")
            return NowPlayingTrack(artist: artist, title: title)
        } else {
            return NowPlayingTrack(artist: "", title: parts[0])
        }
    }
}

extension TrackTrust {
    static func isRealSong(_ track: NowPlayingTrack, shows: [Show]) -> Bool {
        isRealSong(artist: track.artist, title: track.title, shows: shows)
    }

    /// Same song? Compares the way the server stores it.
    static func matches(_ track: NowPlayingTrack, artist: String, title: String) -> Bool {
        normalized(track.artist) == normalized(artist) && normalized(track.title) == normalized(title)
    }
}
