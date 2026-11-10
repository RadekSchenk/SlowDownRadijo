package cz.slowdownradijo.app.reminders

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.Show
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.ZoneId

@RunWith(AndroidJUnit4::class)
class ShowRemindersTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    private val reminders = ShowReminders(context, store)
    /** Monday 9 Nov 2026, 10:15 in Prague. */
    private val now = Instant.parse("2026-11-09T09:15:00Z")

    @Test fun `next starts follow Prague time and skip a show that only continues`() {
        val starts = reminders.upcomingStarts(setOf("the-best-of-slow-down"), now)
        val first = starts.first().second.atZone(ZoneId.of("Europe/Prague"))
        assertEquals(9, first.dayOfMonth)
        assertEquals("12:00", "%02d:%02d".format(first.hour, first.minute))
        // Sunday's last block runs on into Monday's first: no reminder at midnight for that one.
        val midnights = starts.map { it.second.atZone(ZoneId.of("Europe/Prague")) }.filter { it.hour == 0 && it.minute == 0 }
        for (midnight in midnights) {
            val dayBefore = store.day(if (midnight.dayOfWeek.value % 7 + 1 == 1) 7 else midnight.dayOfWeek.value % 7)!!
            assertEquals(false, dayBefore.shows.last().id == "the-best-of-slow-down")
        }
    }

    @Test fun `next airing label`() {
        val bassTime = store.catalog.first { it.id == "bass-time" }
        val label = reminders.nextAiringLabel(bassTime, english = false, now = now)!!
        assertEquals(true, label.endsWith(" v ${bassTime.start}"))
        val english = reminders.nextAiringLabel(bassTime, english = true, now = now)!!
        assertEquals(true, english.endsWith(" at ${bassTime.start}"))
    }

    @Test fun `following is remembered`() {
        val show = Show(id = "x-test", name = "X", start = "10:00", end = "11:00")
        reminders.setFollowing(show, true)
        assertEquals(true, ShowReminders(context, store).isFollowing(show))
        reminders.unfollowAll()
        assertEquals(emptySet<String>(), reminders.followed.value)
    }
}
