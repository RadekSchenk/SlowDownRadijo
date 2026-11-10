package cz.slowdownradijo.app.data

import java.time.Duration
import java.time.Instant

data class RecentSong(val artist: String, val title: String, val playedAt: Instant) {
    val track get() = NowPlayingTrack(artist, title)
}

/**
 * The songs before the one playing now, from the server's play log
 * (`played_tracks`), as `RecentSongs` in `SongHistoryLine.swift`: only
 * from the show on air, newest first, at most ten, stopping at the first
 * gap of more than a quarter of an hour.
 */
object RecentSongs {
    const val LIMIT = 10
    /** Two starts further apart than this mean a hole: a long talk, a mix, or the log missing a stretch. */
    val MAXIMUM_GAP: Duration = Duration.ofMinutes(15)

    suspend fun load(service: RemoteHistoryService, current: NowPlayingTrack, showStart: Instant?, shows: List<Show>, now: Instant = Instant.now()): List<RecentSong> {
        showStart ?: return emptyList()
        val rows = runCatching { service.fetchPage(before = null, windowStart = showStart, limit = 30) }.getOrNull() ?: return emptyList()
        return pick(rows, current, shows, now)
    }

    /** [rows] newest first. */
    fun pick(rows: List<RemotePlayedTrack>, current: NowPlayingTrack, shows: List<Show>, now: Instant): List<RecentSong> {
        val songs = mutableListOf<RecentSong>()
        // The start of the entry after the one being looked at.
        var later = now
        for ((position, row) in rows.withIndex()) {
            val playedAt = row.playedAt
            // The newest entry is usually the song playing now.
            if (position == 0 && TrackTrust.matches(current, row.artist, row.title)) {
                later = playedAt
                continue
            }
            if (Duration.between(playedAt, later) > MAXIMUM_GAP) break
            later = playedAt
            if (!TrackTrust.isRealSong(row.artist, row.title, shows)) continue
            val previous = songs.lastOrNull()
            if (previous != null && TrackTrust.normalized(previous.artist) == TrackTrust.normalized(row.artist) &&
                TrackTrust.normalized(previous.title) == TrackTrust.normalized(row.title)
            ) continue
            songs += RecentSong(row.artist, row.title, playedAt)
            if (songs.size == LIMIT) break
        }
        return songs
    }
}
