package cz.slowdownradijo.app.home

import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.ScheduleStore
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.File
import java.time.Duration
import java.time.Instant

class NowPlayingModelTest {
    private val days = ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText())
    /** Monday 9 Nov 2026, 13:30 in Prague (12:30 UTC): Show podle Majkla, hosted. */
    private var clock = Instant.parse("2026-11-09T12:30:00Z")
    private val song = NowPlayingTrack("Khruangbin", "Maria También")
    private val published = mutableListOf<Pair<String, String>>()

    private fun TestScope.model(logged: Pair<NowPlayingTrack, Instant>? = null) = NowPlayingModel(
        schedule = ScheduleStore(days, now = { clock }),
        scope = this,
        latestLogged = { logged },
        publish = { title, subtitle, _ -> published += title to subtitle },
        now = { clock },
    )

    @Test fun `a title we saw change to is shown`() = runTest {
        val model = model()
        model.onTrack(NowPlayingTrack("Earlier", "Song"))
        clock = clock.plusSeconds(20)
        model.onTrack(song)
        assertEquals(song, model.onAir.value.verifiedTrack)
        assertEquals("Khruangbin – Maria También" to model.onAir.value.show!!.displayTitle, published.last())
    }

    @Test fun `the first title waits for the server log`() = runTest {
        val model = model(logged = song to clock.minusSeconds(90))
        model.onTrack(song)
        assertNull(model.onAir.value.verifiedTrack)
        advanceUntilIdle()
        assertEquals(song, model.onAir.value.verifiedTrack)
    }

    @Test fun `the server log for another song doesn't vouch`() = runTest {
        val model = model(logged = NowPlayingTrack("Other", "Song") to clock)
        model.onTrack(song)
        advanceUntilIdle()
        assertNull(model.onAir.value.verifiedTrack)
    }

    @Test fun `a stuck title disappears after ten minutes`() = runTest {
        val model = model()
        model.onTrack(NowPlayingTrack("Earlier", "Song"))
        model.onTrack(song)
        clock = clock.plus(Duration.ofMinutes(10))
        model.update()
        assertNull(model.onAir.value.verifiedTrack)
    }

    @Test fun `without a song the lock screen shows the show and host`() = runTest {
        val model = model()
        model.update()
        model.publishNowPlaying()
        val show = model.onAir.value.show!!
        assertEquals(show.displayTitle to "Moderuje ${show.hostName}", published.last())
    }
}
