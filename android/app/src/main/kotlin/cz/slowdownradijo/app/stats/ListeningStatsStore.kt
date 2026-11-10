package cz.slowdownradijo.app.stats

import android.content.SharedPreferences
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.l10n.L10nLogic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** What the stats screens show, as `ListeningStatsSummary`. */
data class StatsSummary(
    val todaySeconds: Int = 0,
    val totalSeconds: Int = 0,
    val communitySeconds: Int = 0,
    val rank: Int? = null,
    val rankedListeners: Int = 0,
    val bars: List<DayBar> = emptyList(),
    val weekSeconds: Int = 0,
    val weekStart: LocalDate? = null,
    val weekEnd: LocalDate? = null,
    val shows: List<ShowShare> = emptyList(),
    val showsSeconds: Int = 0,
) {
    data class DayBar(val day: String, val weekday: Int, val seconds: Int, val isPeak: Boolean)

    data class ShowShare(
        val id: String,
        /** `null`: a show the app doesn't know any more. */
        val name: String?,
        val hostName: String?,
        val imageURL: String?,
        val artworkName: String?,
        val seconds: Int,
        val fraction: Double,
    )
}

/** The listener's numbers, as `ListeningStatsStore.swift`: the server's snapshot plus what this phone hasn't sent yet. */
class ListeningStatsStore(
    private val api: StatsApi,
    private val tracker: ListeningTracker,
    private val schedule: ScheduleStore,
    private val prefs: SharedPreferences,
    private val scope: CoroutineScope,
    private val isEnabled: () -> Boolean,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
    private val now: () -> Instant = Instant::now,
) {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    private val _snapshot = MutableStateFlow(prefs.getString(SNAPSHOT, null)?.let { runCatching { json.decodeFromString<StatsSnapshot>(it) }.getOrNull() })
    val snapshot: StateFlow<StatsSnapshot?> = _snapshot.asStateFlow()
    private val _public = MutableStateFlow(prefs.getString(PUBLIC, null)?.let { runCatching { json.decodeFromString<PublicStats>(it) }.getOrNull() })
    val publicStats: StateFlow<PublicStats?> = _public.asStateFlow()
    private val _loadFailed = MutableStateFlow(false)
    val loadFailed: StateFlow<Boolean> = _loadFailed.asStateFlow()

    /** Bumps whenever the numbers change, so screens recompute the summary. */
    private val _version = MutableStateFlow(0)
    val version: StateFlow<Int> = _version.asStateFlow()

    private var loading = false
    private var lastRefresh = Instant.EPOCH

    init {
        scope.launch {
            tracker.events.collect { event ->
                when (event) {
                    ListeningTracker.Event.ACCRUED -> _version.value++
                    ListeningTracker.Event.SYNCED -> refresh(force = true)
                    ListeningTracker.Event.DELETED -> clearLocal()
                }
            }
        }
    }

    val communityUnlocked: Boolean get() = _public.value?.available ?: _snapshot.value?.available ?: false

    suspend fun refreshAll(force: Boolean = false) {
        refreshPublic()
        refresh(force)
    }

    private suspend fun refreshPublic() {
        val stats = runCatching { api.fetchPublicStats() }.getOrNull() ?: return
        _public.value = stats
        prefs.edit().putString(PUBLIC, json.encodeToString(PublicStats.serializer(), stats)).apply()
        _version.value++
    }

    suspend fun refresh(force: Boolean = false) {
        if (!isEnabled() || loading) return
        if (!force && now().epochSecond - lastRefresh.epochSecond < MIN_REFRESH_GAP) return
        // Settle an unconfirmed upload first; its SYNCED refreshes.
        if (tracker.hasUnconfirmedBatch) {
            tracker.retryUnconfirmedBatch()
            return
        }
        loading = true
        try {
            api.fetchMyStats()?.let { fresh ->
                _snapshot.value = fresh
                prefs.edit().putString(SNAPSHOT, json.encodeToString(StatsSnapshot.serializer(), fresh)).apply()
            }
            _loadFailed.value = false
            lastRefresh = now()
        } catch (_: Exception) {
            _loadFailed.value = true
        } finally {
            loading = false
            _version.value++
        }
    }

    private fun clearLocal() {
        _snapshot.value = null
        prefs.edit().remove(SNAPSHOT).apply()
        lastRefresh = Instant.EPOCH
        _version.value++
        scope.launch { refreshPublic() }
    }

    fun summary(at: Instant = now()): StatsSummary {
        val unsynced = tracker.unsyncedRows
        val unsyncedSeconds = unsynced.sumOf { it.seconds }
        val snapshot = _snapshot.value

        val perDay = mutableMapOf<String, MutableMap<String, Int>>()
        for (row in snapshot?.daily.orEmpty()) perDay.getOrPut(row.day) { mutableMapOf() }.merge(row.showId, row.seconds, Int::plus)
        for (row in unsynced) perDay.getOrPut(row.day) { mutableMapOf() }.merge(row.showId, row.seconds, Int::plus)

        val today = at.atZone(zone()).toLocalDate()
        val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
        val daySeconds = days.map { perDay[it.toString()]?.values?.sum() ?: 0 }
        val peak = daySeconds.maxOrNull() ?: 0
        val peakIndex = if (peak > 0) daySeconds.indexOf(peak) else -1
        val bars = days.mapIndexed { i, date ->
            StatsSummary.DayBar(date.toString(), date.dayOfWeek.value % 7 + 1, daySeconds[i], i == peakIndex)
        }

        // Shows over all time: the server's totals plus the unsent; without them, the snapshot's recent days.
        val allTime = mutableMapOf<String, Int>()
        val totals = snapshot?.shows
        if (totals != null) {
            totals.forEach { allTime.merge(it.showId, it.seconds, Int::plus) }
            unsynced.forEach { allTime.merge(it.showId, it.seconds, Int::plus) }
        } else {
            perDay.values.forEach { shows -> shows.forEach { (id, s) -> allTime.merge(id, s, Int::plus) } }
        }
        val showsSeconds = allTime.values.sum()
        val shows = allTime.filter { it.value > 0 }
            .entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .map { (id, seconds) ->
                val show = schedule.knownShow(id)
                StatsSummary.ShowShare(
                    id, show?.displayTitle, show?.hostName, show?.imageURL, show?.artworkName, seconds,
                    if (showsSeconds > 0) seconds.toDouble() / showsSeconds else 0.0,
                )
            }

        return StatsSummary(
            todaySeconds = perDay[today.toString()]?.values?.sum() ?: 0,
            totalSeconds = (snapshot?.totalSeconds ?: 0) + unsyncedSeconds,
            communitySeconds = (snapshot?.communitySeconds ?: _public.value?.communitySeconds ?: 0) + unsyncedSeconds,
            rank = snapshot?.rank,
            rankedListeners = snapshot?.rankedListeners ?: _public.value?.rankedListeners ?: 0,
            bars = bars,
            weekSeconds = daySeconds.sum(),
            weekStart = days.first(),
            weekEnd = days.last(),
            shows = shows,
            showsSeconds = showsSeconds,
        )
    }

    private companion object {
        const val SNAPSHOT = "stats.snapshot"
        const val PUBLIC = "stats.publicStats"
        const val MIN_REFRESH_GAP = 20L
    }
}

/** Numbers and durations in the app's language, as `StatsFormat.swift`. */
object StatsFormat {
    private fun locale(english: Boolean) = if (english) java.util.Locale.US else java.util.Locale.forLanguageTag("cs-CZ")

    fun number(english: Boolean, value: Int): String = java.text.NumberFormat.getIntegerInstance(locale(english)).format(value)

    data class Parts(val days: Int, val hours: Int, val minutes: Int)

    fun parts(seconds: Int): Parts {
        val totalMinutes = maxOf(seconds, 0) / 60
        val totalHours = totalMinutes / 60
        return Parts(totalHours / 24, totalHours % 24, totalMinutes % 60)
    }

    fun duration(english: Boolean, seconds: Int): String {
        val (days, hours, minutes) = parts(seconds)
        val mm = "%02d".format(minutes)
        return when {
            days > 0 -> "${number(english, days)} d $hours h $mm m"
            hours == 0 -> "$minutes m"
            else -> "$hours h $mm m"
        }
    }

    fun compactDuration(english: Boolean, seconds: Int): String {
        if (seconds < 60) return "0"
        val minutes = seconds / 60
        if (minutes < 60) return "$minutes m"
        val format = java.text.NumberFormat.getNumberInstance(locale(english)).apply { maximumFractionDigits = 2; minimumFractionDigits = 0 }
        return "${format.format(minutes / 60.0)} h"
    }

    fun percent(fraction: Double) = "${Math.round(fraction * 100)} %"

    fun dateRange(english: Boolean, from: LocalDate, to: LocalDate): String {
        val pattern = java.time.format.DateTimeFormatter.ofPattern(if (english) "MMM d" else "d. M.", locale(english))
        return "${from.format(pattern)} – ${to.format(pattern)}"
    }

    fun shortDay(english: Boolean, weekday: Int) = L10nLogic.shortDayName(english, weekday)
}
