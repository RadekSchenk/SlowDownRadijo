package cz.slowdownradijo.app.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class RecentSongsTest {
    private val now = Instant.parse("2026-11-09T12:30:00Z")
    private fun row(artist: String, title: String, minutesAgo: Long) =
        RemotePlayedTrack(id = "$artist$title$minutesAgo", artist = artist, title = title, playedAtString = now.minusSeconds(minutesAgo * 60).toString())
    private val shows = listOf(Show("majkl", "Show podle Majkla", "13:00", "14:00"))
    private val current = NowPlayingTrack("Khruangbin", "Maria También")

    @Test fun `skips the song playing now, placeholders and repeats`() {
        val rows = listOf(
            row("Khruangbin", "Maria También", 2),
            row("Men I Trust", "Show Me How", 6),
            row("Men I Trust", "Show Me How", 7),
            row("Slow Down Rádijo", "Show podle Majkla", 10),
            row("Mildlife", "The Magnificent Moon", 12),
        )
        assertEquals(listOf("Show Me How", "The Magnificent Moon"), RecentSongs.pick(rows, current, shows, now).map { it.title })
    }

    @Test fun `stops at a gap of more than a quarter of an hour`() {
        val rows = listOf(
            row("Khruangbin", "Maria También", 2),
            row("Men I Trust", "Show Me How", 10),
            row("Mildlife", "The Magnificent Moon", 26),
        )
        assertEquals(listOf("Show Me How"), RecentSongs.pick(rows, current, shows, now).map { it.title })
    }

    @Test fun `a gap from now counts too, and at most ten`() {
        assertEquals(emptyList<RecentSong>(), RecentSongs.pick(listOf(row("A", "B", 20)), current, shows, now))
        val many = (1..20L).map { row("Artist $it", "Song $it", it * 3) }
        assertEquals(RecentSongs.LIMIT, RecentSongs.pick(many, current, shows, now).size)
    }
}
