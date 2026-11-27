package cz.slowdownradijo.app.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class RadioAlarmTest {
    private val prague = ZoneId.of("Europe/Prague")
    private fun at(local: String) = java.time.LocalDateTime.parse(local).atZone(prague).toInstant()

    @Test fun `weekdays skip the weekend`() {
        val workdays = RadioAlarmSettings(isOn = true, hour = 6, minute = 30, weekdays = setOf(1, 2, 3, 4, 5))
        // Friday 27 Nov 2026, 7:00 → Monday 30 Nov, 6:30.
        assertEquals(at("2026-11-30T06:30"), RadioAlarm.nextFire(at("2026-11-27T07:00"), workdays, prague))
        // Monday 6:00 → the same morning.
        assertEquals(at("2026-11-30T06:30"), RadioAlarm.nextFire(at("2026-11-30T06:00"), workdays, prague))
    }

    @Test fun `once rings at the next time`() {
        val once = RadioAlarmSettings(isOn = true, hour = 6, minute = 30, weekdays = emptySet())
        assertEquals(at("2026-11-24T06:30"), RadioAlarm.nextFire(at("2026-11-23T22:00"), once, prague))
    }

    @Test fun `only on the chosen days`() {
        val sunday = RadioAlarmSettings(isOn = true, hour = 9, minute = 0, weekdays = setOf(7))
        assertEquals(at("2026-11-29T09:00"), RadioAlarm.nextFire(at("2026-11-23T10:00"), sunday, prague))
        assertNull(RadioAlarm.nextFire(Instant.EPOCH, sunday.copy(weekdays = setOf(8)), prague))
    }
}
