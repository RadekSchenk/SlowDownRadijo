package cz.slowdownradijo.app.data

import java.text.Normalizer
import java.time.Duration
import java.time.Instant

/**
 * Whether a title from the stream's metadata is a real song playing right
 * now, as `TrackTrust.swift` (see there for the data behind the rules):
 * not station noise or a show placeholder, its start known, within
 * [MAXIMUM_AGE], and for hosted shows not from before the show began.
 */
object TrackTrust {
    val MAXIMUM_AGE: Duration = Duration.ofMinutes(10)

    private val domain = Regex("^[A-Za-z0-9-]+\\.(cz|sk|com|eu|net|org)$")

    /** Noise and placeholders are never a song, whatever the timing. */
    fun isRealSong(rawArtist: String, rawTitle: String, shows: List<Show>): Boolean {
        val artist = normalized(rawArtist)
        val title = normalized(rawTitle)
        if (artist.isEmpty() || title.isEmpty() || artist == title) return false
        if (artist.contains("slowdown") || artist == "promo" || title == "promo") return false
        if (isDomain(rawArtist) || isDomain(rawTitle)) return false
        val keys = placeholderKeys(shows)
        return listOf(artist, title).none { value -> keys.any { value.contains(it) } }
    }

    fun isRealSong(track: NowPlayingTrack, shows: List<Show>) = isRealSong(track.artist, track.title, shows)

    /** Whether a track that started at [start] can still be playing at [now]. */
    fun isCurrent(start: Instant, now: Instant, showStart: Instant?): Boolean {
        if (Duration.between(start, now) >= MAXIMUM_AGE) return false
        if (showStart != null && start.isBefore(showStart)) return false
        return true
    }

    /** Same song? Compares the way the server stores it. */
    fun matches(track: NowPlayingTrack, artist: String, title: String) =
        normalized(track.artist) == normalized(artist) && normalized(track.title) == normalized(title)

    /** Lowercase, without diacritics, letters and digits only. */
    fun normalized(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .lowercase()
            .filter { it.isLetterOrDigit() }

    private fun placeholderKeys(shows: List<Show>): Set<String> =
        shows.flatMap { listOfNotNull(it.name, it.displayTitle, it.hostName) }
            .map(::normalized)
            .filter { it.length >= 6 }
            .toSet()

    private fun isDomain(text: String) = domain.matches(text.trim())
}
