package cz.slowdownradijo.app.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Duration
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * The weekly programme and what is on at a given moment, as
 * `ScheduleStore.swift` on iOS. The week comes from slowdownradijo.cz
 * ([WebScheduleService]) so specials show in the app; the last week fetched
 * is kept in [cacheFile]. Before the first fetch the bundled
 * `schedule.json` (the catalogue of regular shows, shared with iOS) stands in.
 */
class ScheduleStore(
    bundledDays: List<ScheduleDay>,
    private val cacheFile: File? = null,
    private val now: () -> Instant = Instant::now,
) {
    /** Every regular show once, from the bundled programme. */
    val catalog: List<Show> = bundledDays.flatMap { it.shows }.distinctBy { it.id }

    private val cached: CachedWeek? = cacheFile?.let(::readCache)
    private val _days = MutableStateFlow((cached?.days ?: bundledDays).sortedBy { it.weekday })
    val days: StateFlow<List<ScheduleDay>> = _days.asStateFlow()

    /** Specials from earlier weeks, so their name and photo stay known. */
    private val formerShows = cached?.formerShows.orEmpty().associateBy { it.id }.toMutableMap()
    private val mutex = Mutex()
    private var fetchedAt: Instant = Instant.EPOCH

    fun replaceWeek(days: List<ScheduleDay>) {
        _days.value = days.sortedBy { it.weekday }
    }

    /**
     * Fetches the week unless fetched in the last [REFRESH_INTERVAL]
     * ([force] skips that). On failure the programme stays as it was.
     */
    suspend fun refresh(fetch: suspend (catalog: List<Show>) -> List<ScheduleDay>, force: Boolean = false) {
        if (mutex.isLocked) return
        mutex.withLock {
            if (!force && Duration.between(fetchedAt, now()) < REFRESH_INTERVAL) return
            val fetched = runCatching { fetch(catalog) }.getOrNull()?.sortedBy { it.weekday } ?: return
            fetchedAt = now()
            val regulars = catalog.map { it.id }.toSet()
            var formerChanged = false
            for (show in fetched.flatMap { it.shows }) {
                if (show.id !in regulars && show.id !in formerShows) {
                    formerShows[show.id] = show
                    formerChanged = true
                }
            }
            if (fetched == _days.value && !formerChanged) return
            _days.value = fetched
            cacheFile?.let { file ->
                val text = json.encodeToString(CachedWeek.serializer(), CachedWeek(fetched, formerShows.values.toList()))
                withContext(Dispatchers.IO) { runCatching { file.writeText(text) } }
            }
        }
    }

    fun day(weekday: Int): ScheduleDay? = _days.value.firstOrNull { it.weekday == weekday }

    fun knownShow(id: String): Show? =
        _days.value.firstNotNullOfOrNull { day -> day.shows.firstOrNull { it.id == id } }
            ?: catalog.firstOrNull { it.id == id } ?: formerShows[id]

    /** The show scheduled at [at], if the programme covers that slot. */
    fun currentShow(at: Instant = now()): Show? {
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
    fun progress(show: Show, at: Instant = now()): Double {
        val start = minutes(show.start) ?: return 0.0
        val end = endMinutes(show) ?: return 0.0
        if (end <= start) return 0.0
        val elapsed = at.atZone(STATION_ZONE).secondOfDay() - start * 60
        return (elapsed.toDouble() / ((end - start) * 60)).coerceIn(0.0, 1.0)
    }

    /** Whole minutes left in [show]'s block at [at]. */
    fun remainingMinutes(show: Show, at: Instant = now()): Int {
        val end = endMinutes(show) ?: return 0
        return maxOf(0, end * 60 - at.atZone(STATION_ZONE).secondOfDay()) / 60
    }

    /** The block after [show]: the next one that day, or tomorrow's first. */
    fun nextShow(after: Show, from: Instant = now()): Show? {
        val weekday = from.atZone(STATION_ZONE).weekdaySundayFirst()
        val shows = day(weekday)?.shows ?: return null
        val index = shows.indexOfFirst { it.id == after.id && it.start == after.start }
        if (index >= 0 && index + 1 < shows.size) return shows[index + 1]
        return day(if (weekday == 7) 1 else weekday + 1)?.shows?.firstOrNull()
    }

    /** The moment [show] started, on the day of [relativeTo]. */
    fun startDate(show: Show, relativeTo: Instant = now()): Instant? {
        val start = minutes(show.start) ?: return null
        return relativeTo.atZone(STATION_ZONE).toLocalDate().atStartOfDay(STATION_ZONE).plusMinutes(start.toLong()).toInstant()
    }

    /** The moment [show] ends, on the day of [relativeTo]. */
    fun endDate(show: Show, relativeTo: Instant = now()): Instant? {
        val end = endMinutes(show) ?: return null
        return relativeTo.atZone(STATION_ZONE).toLocalDate().atStartOfDay(STATION_ZONE).plusMinutes(end.toLong()).toInstant()
    }

    @Serializable
    private data class CachedWeek(val days: List<ScheduleDay>, val formerShows: List<Show>)

    companion object {
        /** How long a fetched week counts as fresh. */
        val REFRESH_INTERVAL: Duration = Duration.ofMinutes(15)

        private fun readCache(file: File): CachedWeek? = runCatching {
            json.decodeFromString(CachedWeek.serializer(), file.readText())
        }.getOrNull()?.takeIf { it.days.size == 7 }

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
