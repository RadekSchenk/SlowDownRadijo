package cz.slowdownradijo.app.winter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

class WinterSeasonTest {
    @Test fun `first Sunday of Advent`() {
        assertEquals(LocalDate.of(2024, 12, 1), WinterSeason.firstAdventSunday(2024))
        assertEquals(LocalDate.of(2025, 11, 30), WinterSeason.firstAdventSunday(2025))
        assertEquals(LocalDate.of(2026, 11, 29), WinterSeason.firstAdventSunday(2026))
        assertEquals(LocalDate.of(2027, 11, 28), WinterSeason.firstAdventSunday(2027))
        assertEquals(LocalDate.of(2028, 12, 3), WinterSeason.firstAdventSunday(2028))
    }

    @Test fun `from Advent to Epiphany`() {
        assertFalse(WinterSeason.isSeason(LocalDate.of(2026, 11, 28)))
        assertTrue(WinterSeason.isSeason(LocalDate.of(2026, 11, 29)))
        assertTrue(WinterSeason.isSeason(LocalDate.of(2026, 12, 31)))
        assertTrue(WinterSeason.isSeason(LocalDate.of(2027, 1, 6)))
        assertFalse(WinterSeason.isSeason(LocalDate.of(2027, 1, 7)))
        assertFalse(WinterSeason.isSeason(LocalDate.of(2026, 10, 15)))
        assertFalse(WinterSeason.isSeason(LocalDate.of(2027, 11, 27)))
    }

    @Test fun `days change at Prague's midnight`() {
        // 28 Nov 23:30 UTC is already 29 Nov 00:30 in Prague.
        assertTrue(WinterSeason.isSeason(Instant.parse("2026-11-28T23:30:00Z")))
        assertFalse(WinterSeason.isSeason(Instant.parse("2026-11-28T22:30:00Z")))
        // 6 Jan 23:30 UTC is 7 Jan in Prague.
        assertFalse(WinterSeason.isSeason(Instant.parse("2027-01-06T23:30:00Z")))
    }

    @Test fun christmas() {
        assertFalse(WinterSeason.isChristmas(LocalDate.of(2026, 12, 23)))
        assertTrue(WinterSeason.isChristmas(LocalDate.of(2026, 12, 24)))
        assertTrue(WinterSeason.isChristmas(LocalDate.of(2026, 12, 26)))
        assertFalse(WinterSeason.isChristmas(LocalDate.of(2026, 12, 27)))
    }
}
