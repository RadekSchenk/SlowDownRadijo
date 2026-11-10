package cz.slowdownradijo.app.home

import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.data.TrackTrust
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

/** What the home header shows about what's on air. */
data class OnAir(
    val show: Show? = null,
    /** 0…1 of the show's block. */
    val progress: Double = 0.0,
    /** When the show ends, for the countdown and "end of show" sleep timer. */
    val showEnd: Instant? = null,
    /** When it began (yesterday for one that started before midnight). */
    val showStart: Instant? = null,
    /** The song, only while [TrackTrust] vouches for it. */
    val verifiedTrack: NowPlayingTrack? = null,
)

/**
 * The show on air and the song playing, as `NowPlayingViewModel.swift`:
 * the show from the programme every 20 s, the song from the stream's
 * metadata shown only when [TrackTrust] is sure it is a real song playing
 * now. A title we watched change is dated by that change; the first one
 * after launch waits for the server log (`played_tracks`) to say when it
 * started, asked at most once a minute.
 *
 * [publish] gets the notification's and lock screen's title and subtitle.
 */
class NowPlayingModel(
    private val schedule: ScheduleStore,
    private val scope: CoroutineScope,
    /** The server's latest logged song in the last three hours, if any. */
    private val latestLogged: suspend () -> Pair<NowPlayingTrack, Instant>?,
    private val publish: (title: String, subtitle: String, show: Show?) -> Unit = { _, _, _ -> },
    private val hostedByKicker: () -> String = { "Moderuje" },
    private val now: () -> Instant = Instant::now,
) {
    private val _onAir = MutableStateFlow(OnAir())
    val onAir: StateFlow<OnAir> = _onAir.asStateFlow()

    var track: NowPlayingTrack? = null
        private set
    private var trackConfirmedStart: Instant? = null
    private var lastServerCheck: Instant = Instant.EPOCH
    private var serverCheck: Job? = null

    /** Ticks every 20 s (and when the week changes); [refreshSchedule] runs on each tick. */
    fun start(trackFlow: StateFlow<NowPlayingTrack?>, refreshSchedule: suspend () -> Unit) {
        scope.launch { trackFlow.collect { onTrack(it) } }
        scope.launch { schedule.days.drop(1).collect { update() } }
        scope.launch {
            while (isActive) {
                update()
                refreshSchedule()
                delay(TICK.toMillis())
            }
        }
    }

    fun onTrack(newTrack: NowPlayingTrack?) {
        if (newTrack == track) return
        // A change we watched dates the new title; the first after launch
        // could have been there an hour, so it waits for the server log.
        trackConfirmedStart = if (track != null && newTrack != null) now() else null
        serverCheck?.cancel()
        lastServerCheck = Instant.EPOCH
        track = newTrack
        update()
    }

    fun update() {
        val at = now()
        val show = schedule.currentShow(at)
        val start = show?.let { schedule.startDate(it, at) }?.let { if (it.isAfter(at)) it.minus(Duration.ofDays(1)) else it }
        val verified = verifiedTrack(at, show)
        val next = OnAir(
            show = show,
            progress = show?.let { schedule.progress(it, at) } ?: 0.0,
            showEnd = show?.let { schedule.endDate(it, at) },
            showStart = start,
            verifiedTrack = verified,
        )
        val changed = next.show != _onAir.value.show || next.verifiedTrack != _onAir.value.verifiedTrack
        _onAir.value = next
        if (changed) publishNowPlaying()
    }

    fun publishNowPlaying() {
        val state = _onAir.value
        val showTitle = state.show?.displayTitle ?: STATION
        val song = state.verifiedTrack
        if (song != null) {
            publish("${song.artist} – ${song.title}", showTitle, state.show)
        } else {
            publish(showTitle, state.show?.hostName?.let { "${hostedByKicker()} $it" } ?: STATION, state.show)
        }
    }

    private fun verifiedTrack(at: Instant, show: Show?): NowPlayingTrack? {
        val track = track ?: return null
        val shows = schedule.days.value.flatMap { it.shows }
        if (!TrackTrust.isRealSong(track, shows)) return null
        val start = trackConfirmedStart
        if (start == null) {
            if (Duration.between(lastServerCheck, at) >= SERVER_CHECK_INTERVAL) checkServerStart(track)
            return null
        }
        val showStart = if (show?.hostName == null) null else schedule.startDate(show, at)
        return if (TrackTrust.isCurrent(start, at, showStart)) track else null
    }

    private fun checkServerStart(track: NowPlayingTrack) {
        lastServerCheck = now()
        serverCheck?.cancel()
        serverCheck = scope.launch {
            val (logged, playedAt) = runCatching { latestLogged() }.getOrNull() ?: return@launch
            if (this@NowPlayingModel.track != track || !TrackTrust.matches(track, logged.artist, logged.title)) return@launch
            trackConfirmedStart = playedAt
            update()
        }
    }

    companion object {
        const val STATION = "Slow Down Rádijo"
        val TICK: Duration = Duration.ofSeconds(20)
        val SERVER_CHECK_INTERVAL: Duration = Duration.ofSeconds(60)
    }
}
