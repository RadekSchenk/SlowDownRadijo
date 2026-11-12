package cz.slowdownradijo.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId

class ScheduleStoreTest {
    /** The iOS app's schedule.json, the same file the app bundles. */
    private val days = ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText())
    private val store = ScheduleStore(days)
    private fun prague(text: String) = LocalDateTime.parse(text).atZone(ZoneId.of("Europe/Prague")).toInstant()

    @Test fun `the bundled week has seven days, each covered from midnight to midnight`() {
        assertEquals((1..7).toList(), store.days.value.map { it.weekday })
        for (day in store.days.value) {
            assertEquals("day ${day.weekday} starts at midnight", 0, ScheduleStore.minutes(day.shows.first().start))
            assertEquals("day ${day.weekday} ends at midnight", 1440, ScheduleStore.endMinutes(day.shows.last()))
            day.shows.zipWithNext().forEach { (a, b) -> assertEquals("gap on ${day.dayName}", a.end, b.start) }
        }
    }

    @Test fun `every photo schedule json names is bundled`() {
        for (show in store.catalog) {
            show.artworkName?.let { assertNotNull("artwork $it", SharedImages.drawable(it)) }
            show.hostImageName?.let { assertNotNull("host photo $it", SharedImages.drawable(it)) }
        }
    }

    @Test fun `current show follows Prague time`() {
        // Monday 2026-11-09, 09:30 in Prague.
        val show = store.currentShow(prague("2026-11-09T09:30:00"))
        assertNotNull(show)
        val monday = store.day(2)!!
        val expected = monday.shows.first { ScheduleStore.minutes(it.start)!! <= 570 && 570 < ScheduleStore.endMinutes(it)!! }
        assertEquals(expected.id, show!!.id)
    }

    @Test fun `progress and remaining minutes`() {
        val monday = store.day(2)!!
        val show = monday.shows.first()
        val start = ScheduleStore.minutes(show.start)!!
        val end = ScheduleStore.endMinutes(show)!!
        val middle = start + (end - start) / 2
        val at = prague("2026-11-09T%02d:%02d:00".format(middle / 60, middle % 60))
        assertEquals(0.5, store.progress(show, at), 0.02)
        assertEquals(end - middle, store.remainingMinutes(show, at))
    }

    @Test fun `next show after the day's last is tomorrow's first`() {
        val sunday = store.day(1)!!
        val next = store.nextShow(sunday.shows.last(), prague("2026-11-08T23:30:00"))
        assertEquals(store.day(2)!!.shows.first().id, next?.id)
    }

    @Test fun `localized name swaps the Czech s for with`() {
        val show = store.catalog.first { it.title != null && it.name.contains(" s ") }
        assertTrue(show.localizedName(english = true).contains(" with "))
        assertEquals(show.name, show.localizedName(english = false))
        assertNull(Show(id = "x", name = "Rotation s ", start = "00:00", end = "01:00").title)
    }
}
