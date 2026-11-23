package cz.slowdownradijo.app.winter

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.Month
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

/**
 * "Zimní vzhled", as `WinterSeason.swift` (Figma "Advent ❄︎", docs/winter.md):
 * from the first Sunday of Advent to Epiphany (6 January, inclusive) the home
 * header snows and the logo's sun hangs as a Christmas bauble. Dates are
 * Prague's. The listener can turn it off in Settings ([cz.slowdownradijo.app.AppSettings.winterLook]).
 *
 * iOS also shows a winter splash once a day; Android has no splash of its own
 * (the system's shows the launcher icon, which is the winter one in 1.4).
 */
object WinterSeason {
    private val prague: ZoneId = ZoneId.of("Europe/Prague")

    fun today(now: Instant = Instant.now()): LocalDate = now.atZone(prague).toLocalDate()

    /** Four Sundays before Christmas: between 27 November and 3 December. */
    fun firstAdventSunday(year: Int): LocalDate =
        LocalDate.of(year, Month.DECEMBER, 24)
            .with(TemporalAdjusters.previousOrSame(DayOfWeek.SUNDAY))
            .minusWeeks(3)

    fun isSeason(day: LocalDate): Boolean = when {
        day.month == Month.JANUARY -> day.dayOfMonth <= 6
        day.monthValue >= 11 -> !day.isBefore(firstAdventSunday(day.year))
        else -> false
    }

    fun isSeason(now: Instant): Boolean = isSeason(today(now))

    /** 24–26 December. */
    fun isChristmas(day: LocalDate): Boolean = day.month == Month.DECEMBER && day.dayOfMonth in 24..26
}
