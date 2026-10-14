import Foundation

/// Decides whether a title from the stream's ICY metadata is a real song
/// that is playing right now — the home screen shows the track only then.
///
/// Built from three weeks of `played_tracks` (Oct 2026): real songs change
/// every 3–4 minutes; everything else is one of these:
///
/// * **Station noise**, sent under the artist "SLOWDOWN": PROMO, sponsors
///   (hymer.cz, brylarna.cz, grillhamr.cz), show announcements.
/// * **Show placeholders**: pre-recorded shows put the show or host in the
///   metadata ("BEATBRUNCH – Jaro Cossiga", "DJ POEM – Mixtape Madley",
///   "Britský State of Mind – C. Monts") and leave it for the whole hour.
/// * **Stuck titles**: the first song of a mix that stays in the metadata
///   for 50–120 minutes.
///
/// So a track is shown only when it isn't noise or a placeholder, we know
/// when it started (we saw it change, or the server logged its start), it
/// started within the last `maximumAge`, and — for hosted shows — not
/// before the show itself began.
enum TrackTrust {
    /// Longer than almost any real song in the data (99.8% are shorter);
    /// a title unchanged for longer than this is stuck.
    static let maximumAge: TimeInterval = 10 * 60

    /// Noise and placeholders — never a song, whatever the timing.
    static func isRealSong(_ track: NowPlayingTrack, shows: [Show]) -> Bool {
        let artist = normalized(track.artist)
        let title = normalized(track.title)
        guard !artist.isEmpty, !title.isEmpty, artist != title else { return false }

        // Station noise.
        if artist.contains("slowdown") || artist == "promo" || title == "promo" { return false }
        if isDomain(track.artist) || isDomain(track.title) { return false }

        // The show or its host standing in for a song.
        let keys = placeholderKeys(for: shows)
        for value in [artist, title] where keys.contains(where: { value.contains($0) }) {
            return false
        }
        return true
    }

    /// Whether a track that started at `start` can still be playing at
    /// `now`. `showStart` is the current show's start when it has a host:
    /// a title from before then belongs to the previous programme.
    static func isCurrent(start: Date, now: Date, showStart: Date?) -> Bool {
        guard now.timeIntervalSince(start) < maximumAge else { return false }
        if let showStart, start < showStart { return false }
        return true
    }

    /// Same song? Compares the way the server stores it.
    static func matches(_ track: NowPlayingTrack, artist: String, title: String) -> Bool {
        normalized(track.artist) == normalized(artist) && normalized(track.title) == normalized(title)
    }

    /// Lowercase, without diacritics, letters and digits only:
    /// "Groove LABl" → "groovelabl", "Matěj" → "matej".
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Show titles, full names and host names, long enough not to match by
    /// accident ("Bass Time", "C. Monts", "DJ Poem", "Jaro Cossiga").
    private static func placeholderKeys(for shows: [Show]) -> Set<String> {
        var keys = Set<String>()
        for show in shows {
            for text in [show.name, show.displayTitle, show.hostName].compactMap({ $0 }) {
                let key = normalized(text)
                if key.count >= 6 { keys.insert(key) }
            }
        }
        return keys
    }

    private static func isDomain(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces)
            .range(of: #"^[A-Za-z0-9-]+\.(cz|sk|com|eu|net|org)$"#, options: .regularExpression) != nil
    }
}
