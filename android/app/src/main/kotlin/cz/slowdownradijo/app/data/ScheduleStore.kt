package cz.slowdownradijo.app.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * The weekly programme and what is on at a given moment, as
 * `ScheduleStore.swift` on iOS. Starts from the bundled `schedule.json`
 * (the catalogue of regular shows, shared with iOS); the web's week
 * replaces it once fetched.
 */
class ScheduleStore(bundledDays: List<ScheduleDay>) {
    private val _days = MutableStateFlow(bundledDays.sortedBy { it.weekday })
    val days: StateFlow<List<ScheduleDay>> = _days.asStateFlow()

    /** Every regular show once, from the bundled programme. */
    val catalog: List<Show> = bundledDays.flatMap { it.shows }.distinctBy { it.id }

    fun replaceWeek(days: List<ScheduleDay>) {
        _days.value = days.sortedBy { it.weekday }
    }

    fun day(weekday: Int): ScheduleDay? = _days.value.firstOrNull { it.weekday == weekday }

    fun knownShow(id: String): Show? =
        _days.value.firstNotNullOfOrNull { day -> day.shows.firstOrNull { it.id == id } }
            ?: catalog.firstOrNull { it.id == id }

    /** The show scheduled at [at], if the programme covers that slot. */
    fun currentShow(at: Instant = Instant.now()): Show? {
        val time = at.atZone(STATION_ZONE)
        val day = day(time.weekdaySundayFirst()) ?: return null
        val minute = time.hour * 60 + time.minute
        return day.shows.firstOrNull { show ->
            val start = minutes(show.start) ?: return@firstOrNull false
            val end = endMinutes(show) ?: return@firstOrNull false
            minute in start until end
        }
    }

    /** Fraction (0...1) of [show]'s block that has passed at [at]. */
    fun progress(show: Show, at: Instant = Instant.now()): Double {
        val start = minutes(show.start) ?: return 0.0
        val end = endMinutes(show) ?: return 0.0
        if (end <= start) return 0.0
        val elapsed = at.atZone(STATION_ZONE).secondOfDay() - start * 60
        return (elapsed.toDouble() / ((end - start) * 60)).coerceIn(0.0, 1.0)
    }

    /** Whole minutes left in [show]'s block at [at]. */
    fun remainingMinutes(show: Show, at: Instant = Instant.now()): Int {
        val end = endMinutes(show) ?: return 0
        return maxOf(0, end * 60 - at.atZone(STATION_ZONE).secondOfDay()) / 60
    }

    /** The block after [show]: the next one that day, or tomorrow's first. */
    fun nextShow(after: Show, from: Instant = Instant.now()): Show? {
        val weekday = from.atZone(STATION_ZONE).weekdaySundayFirst()
        val shows = day(weekday)?.shows ?: return null
        val index = shows.indexOfFirst { it.id == after.id && it.start == after.start }
        if (index >= 0 && index + 1 < shows.size) return shows[index + 1]
        return day(if (weekday == 7) 1 else weekday + 1)?.shows?.firstOrNull()
    }

    /** The moment [show] started, on the day of [relativeTo]. */
    fun startDate(show: Show, relativeTo: Instant = Instant.now()): Instant? {
        val start = minutes(show.start) ?: return null
        return relativeTo.atZone(STATION_ZONE).toLocalDate().atStartOfDay(STATION_ZONE).plusMinutes(start.toLong()).toInstant()
    }

    /** The moment [show] ends, on the day of [relativeTo]. */
    fun endDate(show: Show, relativeTo: Instant = Instant.now()): Instant? {
        val end = endMinutes(show) ?: return null
        return relativeTo.atZone(STATION_ZONE).toLocalDate().atStartOfDay(STATION_ZONE).plusMinutes(end.toLong()).toInstant()
    }

    companion object {
        /** The programme's times are the station's own, Prague time. */
        val STATION_ZONE: ZoneId = ZoneId.of("Europe/Prague")

        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

        fun parse(text: String): List<ScheduleDay> = json.decodeFromString<Schedule>(text).days

        /** `schedule.json` from the app's assets (synced from the iOS app). */
        fun bundled(context: Context): List<ScheduleDay> =
            context.assets.open("schedule.json").bufferedReader().use { parse(it.readText()) }

        fun minutes(time: String): Int? {
            val parts = time.split(":")
            if (parts.size != 2) return null
            val hour = parts[0].toIntOrNull() ?: return null
            val minute = parts[1].toIntOrNull() ?: return null
            return hour * 60 + minute
        }

        /** A block's end in minutes; "00:00" means midnight at the day's end. */
        fun endMinutes(show: Show): Int? = minutes(show.end)?.let { if (it == 0) 1440 else it }

        /** Sunday-first 1...7, as iOS `Calendar.component(.weekday)` and schedule.json. */
        fun ZonedDateTime.weekdaySundayFirst(): Int =
            if (dayOfWeek == DayOfWeek.SUNDAY) 1 else dayOfWeek.value + 1

        private fun ZonedDateTime.secondOfDay(): Int = toLocalTime().toSecondOfDay()
    }
}
