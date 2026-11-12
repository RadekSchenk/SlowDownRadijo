package cz.slowdownradijo.app.stats

import android.content.SharedPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/**
 * Counts the seconds the radio plays, per day and show, and sends them to
 * the stats server in batches, as `ListeningTracker.swift`: a tick every
 * 10 s (at most 30 s credited per tick), a routine upload once a minute
 * has built up (at most every 5 min) and a prompt one when playback stops
 * (10 s, at most every 30 s). A batch keeps its id until the server
 * confirms it, so a retry never counts twice. Turning stats off drops
 * everything unsent.
 */
class ListeningTracker(
    private val api: StatsApi,
    private val prefs: SharedPreferences,
    private val scope: CoroutineScope,
    private val isEnabled: () -> Boolean,
    private val showProvider: () -> String?,
    private val appVersion: String,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
    private val now: () -> Instant = Instant::now,
    private val tickMillis: Long = 10_000,
) {
    enum class Event { ACCRUED, SYNCED, DELETED }

    @Serializable
    private data class Batch(val id: String, val rows: List<ListeningRow>)

    @Serializable
    private data class Queue(val pending: MutableList<ListeningRow> = mutableListOf(), var inflight: Batch? = null)

    private val json = Json { ignoreUnknownKeys = true }
    private var queue: Queue = prefs.getString(KEY, null)?.let { runCatching { json.decodeFromString<Queue>(it) }.getOrNull() } ?: Queue()

    private val _events = MutableSharedFlow<Event>(extraBufferCapacity = 16)
    val events: SharedFlow<Event> = _events.asSharedFlow()

    private val _measuring = MutableStateFlow(false)
    /** Counting right now (the radio plays and stats are on). */
    val measuring: StateFlow<Boolean> = _measuring.asStateFlow()

    private var playerIsPlaying = false
    private var lastTick: Instant? = null
    private var carry = 0.0
    private var ticker: Job? = null
    private var flushJob: Job? = null
    private var lastFlushAttempt = Instant.EPOCH

    val unsyncedRows: List<ListeningRow> get() = queue.inflight?.rows.orEmpty() + queue.pending
    val hasUnconfirmedBatch: Boolean get() = queue.inflight != null

    fun update(isPlaying: Boolean) {
        accrue()
        playerIsPlaying = isPlaying
        refreshAccruing()
        if (!_measuring.value) flush(immediate = true)
    }

    /** The app went to the background: send what there is. */
    fun onBackground() {
        accrue()
        flush(immediate = true)
    }

    fun retryUnconfirmedBatch() {
        if (queue.inflight != null) flush(immediate = true)
    }

    fun enabledPreferenceChanged() {
        accrue()
        if (!isEnabled()) {
            // Off means off: nothing measured, nothing unsent kept, an upload under way cancelled.
            flushJob?.cancel()
            queue = Queue()
            carry = 0.0
            save()
            _events.tryEmit(Event.DELETED)
        }
        refreshAccruing()
    }

    suspend fun deleteAllData() {
        queue = Queue()
        carry = 0.0
        save()
        // A batch on its way must land before the delete, or it would bring the rows back.
        flushJob?.join()
        api.deleteMyData()
        _events.tryEmit(Event.DELETED)
    }

    private fun refreshAccruing() {
        val should = playerIsPlaying && isEnabled()
        if (should == _measuring.value) return
        _measuring.value = should
        if (should) {
            lastTick = now()
            ticker = scope.launch {
                while (isActive) {
                    delay(tickMillis)
                    accrue()
                    flush(immediate = false)
                }
            }
        } else {
            lastTick = null
            ticker?.cancel()
            ticker = null
        }
    }

    fun accrue(at: Instant = now()) {
        if (!_measuring.value) return
        val last = lastTick ?: return
        val delta = ((at.toEpochMilli() - last.toEpochMilli()) / 1000.0).coerceIn(0.0, MAX_CREDIT_PER_TICK)
        lastTick = at
        carry += delta
        val whole = carry.toInt()
        if (whole <= 0) return
        carry -= whole
        val day = dayString(at, zone())
        val show = showProvider() ?: UNKNOWN_SHOW
        val row = queue.pending.firstOrNull { it.day == day && it.showId == show }
        if (row != null) row.seconds += whole else queue.pending += ListeningRow(day, show, whole)
        save()
        _events.tryEmit(Event.ACCRUED)
    }

    fun flush(immediate: Boolean) {
        if (!isEnabled() || flushJob?.isActive == true) return
        val at = now()
        val gap = if (immediate) IMMEDIATE_FLUSH_GAP else ROUTINE_FLUSH_GAP
        if (at.epochSecond - lastFlushAttempt.epochSecond < gap) return

        if (queue.inflight == null) {
            val pendingSeconds = queue.pending.sumOf { it.seconds }
            if (pendingSeconds < if (immediate) IMMEDIATE_THRESHOLD else ROUTINE_THRESHOLD) return
            val rows = queue.pending.take(MAX_ROWS_PER_BATCH).map { it.copy() }
            repeat(rows.size) { queue.pending.removeAt(0) }
            queue.inflight = Batch(UUID.randomUUID().toString(), rows)
            save()
        }
        val batch = queue.inflight ?: return
        lastFlushAttempt = at
        flushJob = scope.launch {
            val settled = try {
                api.recordListening(batch.id, batch.rows, appVersion)
                true
            } catch (_: StatsApi.Failure.Rejected) {
                true // never accepted as it is: drop instead of retrying forever
            } catch (_: Exception) {
                false // offline or server trouble: retried later under the same id
            }
            if (settled && queue.inflight?.id == batch.id) {
                queue.inflight = null
                save()
                _events.tryEmit(Event.SYNCED)
            }
        }
    }

    private fun save() = prefs.edit().putString(KEY, json.encodeToString(Queue.serializer(), queue)).apply()

    companion object {
        const val UNKNOWN_SHOW = "_"
        private const val KEY = "stats.listeningQueue"
        private const val MAX_CREDIT_PER_TICK = 30.0
        private const val ROUTINE_THRESHOLD = 60
        private const val ROUTINE_FLUSH_GAP = 300L
        private const val IMMEDIATE_THRESHOLD = 10
        private const val IMMEDIATE_FLUSH_GAP = 30L
        private const val MAX_ROWS_PER_BATCH = 200

        /** "2026-11-10" in the phone's time zone, as on iOS. */
        fun dayString(at: Instant, zone: ZoneId): String = at.atZone(zone).toLocalDate().toString()
    }
}
