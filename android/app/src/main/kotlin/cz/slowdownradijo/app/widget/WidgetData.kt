package cz.slowdownradijo.app.widget

import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.RemotePlayedTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.data.TrackTrust
import java.time.Duration
import java.time.Instant

/** What the widget shows (`NowPlayingEntry.swift`). */
data class WidgetEntry(val show: Show?, val track: NowPlayingTrack?)

/**
 * The widget's content and when to look again, as `NowPlayingProvider.swift`:
 * the show on air, and the server log's latest song only while
 * [TrackTrust] vouches for it. Next look in 15 minutes, or when the show
 * ends, or when the song can't be playing any more, whichever is first.
 */
object WidgetData {
    val REFRESH: Duration = Duration.ofMinutes(15)

    fun entry(schedule: ScheduleStore, latest: RemotePlayedTrack?, now: Instant): Pair<WidgetEntry, Instant> {
        val show = schedule.currentShow(now)
        val track = latest?.takeIf { verified(it, show, schedule, now) }
        var reload = now.plus(REFRESH)
        show?.let { schedule.endDate(it, now) }?.takeIf { it.isAfter(now) && it.isBefore(reload) }?.let { reload = it }
        track?.let { latest.playedAt.plus(TrackTrust.MAXIMUM_AGE) }?.takeIf { it.isAfter(now) && it.isBefore(reload) }?.let { reload = it }
        return WidgetEntry(show, track?.let { NowPlayingTrack(it.artist, it.title) }) to reload
    }

    private fun verified(track: RemotePlayedTrack, show: Show?, schedule: ScheduleStore, now: Instant): Boolean {
        val shows = schedule.days.value.flatMap { it.shows }
        if (!TrackTrust.isRealSong(track.artist, track.title, shows)) return false
        val showStart = if (show?.hostName == null) null else schedule.startDate(show, now)
        return TrackTrust.isCurrent(track.playedAt, now, showStart)
    }
}
