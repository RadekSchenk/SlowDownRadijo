package cz.slowdownradijo.app.data

import java.net.URLEncoder

/**
 * A song from the stream's ICY `StreamTitle`, as `NowPlayingTrack.swift`:
 * "STATION - ARTIST - TITLE" or "ARTIST - TITLE".
 */
data class NowPlayingTrack(val artist: String, val title: String) {
    val displayText: String
        get() = when {
            artist.isEmpty() -> title
            title.isEmpty() -> artist
            else -> "$artist — $title"
        }

    companion object {
        fun parse(streamTitle: String): NowPlayingTrack? {
            val trimmed = streamTitle.trim()
            if (trimmed.isEmpty()) return null
            val parts = trimmed.split(" - ").map { it.trim() }.toMutableList()
            // The station prefixes its name ("SLOWDOWN") on every title; drop it.
            if (parts.size > 2 && parts[0].equals("SLOWDOWN", ignoreCase = true)) parts.removeAt(0)
            return if (parts.size >= 2) {
                NowPlayingTrack(parts[0], parts.drop(1).joinToString(" - "))
            } else {
                NowPlayingTrack("", parts[0])
            }
        }
    }
}

/** A Spotify search for the song, as `spotifySearchURL` on iOS. */
fun spotifySearchUrl(artist: String, title: String): String? {
    val query = "$artist $title".trim()
    if (query.isEmpty()) return null
    return "https://open.spotify.com/search/" + URLEncoder.encode(query, "UTF-8").replace("+", "%20")
}
