package cz.slowdownradijo.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Instant

class TrackTrustTest {
    private val shows = ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()).flatMap { it.shows }

    @Test fun `real songs pass`() {
        assertTrue(TrackTrust.isRealSong("Khruangbin", "Maria También", shows))
    }

    @Test fun `station noise, domains and promos are not songs`() {
        assertFalse(TrackTrust.isRealSong("SLOWDOWN", "PROMO", shows))
        assertFalse(TrackTrust.isRealSong("Slow Down", "hymer.cz", shows))
        assertFalse(TrackTrust.isRealSong("brylarna.cz", "Jaro", shows))
        assertFalse(TrackTrust.isRealSong("Same", "same", shows))
        assertFalse(TrackTrust.isRealSong("", "Title", shows))
    }

    @Test fun `show placeholders are not songs`() {
        assertFalse(TrackTrust.isRealSong("BEATBRUNCH", "Jaro Cossiga", shows))
        assertFalse(TrackTrust.isRealSong("DJ POEM", "Mixtape Madley", shows))
    }

    @Test fun `timing rules`() {
        val start = Instant.parse("2026-11-10T10:00:00Z")
        assertTrue(TrackTrust.isCurrent(start, start.plusSeconds(9 * 60), null))
        assertFalse(TrackTrust.isCurrent(start, start.plusSeconds(10 * 60), null))
        assertFalse(TrackTrust.isCurrent(start, start.plusSeconds(60), showStart = start.plusSeconds(30)))
    }

    @Test fun `normalized folds case and diacritics`() {
        assertEquals("matej", TrackTrust.normalized("Matěj"))
        assertEquals("groovelabl", TrackTrust.normalized("Groove LABl"))
    }

    @Test fun `stream titles parse without the station prefix`() {
        assertEquals(NowPlayingTrack("Artist", "Title - Remix"), NowPlayingTrack.parse("SLOWDOWN - Artist - Title - Remix"))
        assertEquals(NowPlayingTrack("", "Jingle"), NowPlayingTrack.parse(" Jingle "))
        assertNull(NowPlayingTrack.parse("  "))
        assertEquals("https://open.spotify.com/search/Bon%20Iver%20Holocene", spotifySearchUrl("Bon Iver", "Holocene"))
    }
}
