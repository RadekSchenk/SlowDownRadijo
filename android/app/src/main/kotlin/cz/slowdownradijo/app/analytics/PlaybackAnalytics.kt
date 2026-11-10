package cz.slowdownradijo.app.analytics

import android.content.SharedPreferences
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.player.RadioEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Listening sessions for analytics, as `PlaybackAnalytics.swift`: how long
 * connecting took, how long the radio was really heard, reconnects within
 * a session, why it stopped, and a session the app never saw end (killed
 * while playing) sent at the next launch as "app_closed".
 */
class PlaybackAnalytics(
    private val engine: RadioEngine,
    private val analytics: Analytics,
    private val prefs: SharedPreferences,
    private val currentShowId: () -> String?,
    private val output: () -> String,
    private val now: () -> Long = System::currentTimeMillis,
) {
    @Serializable
    private data class OpenSession(val seconds: Double, val showId: String?, val reconnects: Int, val output: String)

    private var connectingSince: Long? = null
    private var inSession = false
    private var playingSince: Long? = null
    private var heardSeconds = 0.0
    private var reconnects = 0
    private var dropped = false
    private var failureReported = false

    fun start(scope: CoroutineScope) {
        prefs.getString(OPEN, null)?.let { saved ->
            prefs.edit().remove(OPEN).apply()
            runCatching { Json.decodeFromString<OpenSession>(saved) }.getOrNull()?.let {
                analytics.track(AnalyticsEvent.PlaybackStopped(it.seconds.toInt(), "app_closed", it.showId, it.reconnects, it.output))
            }
        }
        scope.launch { engine.state.collect(::handle) }
    }

    fun handle(state: PlaybackState) {
        val at = now()
        when (state) {
            PlaybackState.Connecting -> {
                pauseClock(at)
                if (!inSession && connectingSince == null) connectingSince = at
            }
            PlaybackState.Playing -> {
                if (!inSession) {
                    inSession = true
                    heardSeconds = 0.0
                    reconnects = 0
                    dropped = false
                    val connectMs = connectingSince?.let { (at - it).toInt() }
                    connectingSince = null
                    analytics.track(AnalyticsEvent.PlaybackStarted(engine.lastPlayTrigger.analyticsName, currentShowId(), connectMs, output()))
                } else if (dropped) {
                    dropped = false
                    reconnects++
                }
                playingSince = at
                failureReported = false
                save(at)
            }
            PlaybackState.Error -> {
                pauseClock(at)
                if (inSession) dropped = true
                if (failureReported) return
                failureReported = true
                analytics.track(AnalyticsEvent.PlaybackFailed(if (inSession) "interrupted" else "connecting", currentShowId()))
            }
            PlaybackState.Paused, PlaybackState.Idle -> {
                pauseClock(at)
                connectingSince = null
                failureReported = false
                if (!inSession) return
                inSession = false
                prefs.edit().remove(OPEN).apply()
                analytics.track(AnalyticsEvent.PlaybackStopped(heardSeconds.toInt(), engine.lastStopReason.analyticsName, currentShowId(), reconnects, output()))
            }
        }
    }

    private fun pauseClock(at: Long) {
        playingSince?.let { heardSeconds += (at - it) / 1000.0 }
        playingSince = null
        save(at)
    }

    /** Called now and then while playing, so a killed app still reports roughly how long it played. */
    fun save(at: Long = now()) {
        if (!inSession) return
        val seconds = heardSeconds + (playingSince?.let { (at - it) / 1000.0 } ?: 0.0)
        prefs.edit().putString(OPEN, Json.encodeToString(OpenSession.serializer(), OpenSession(seconds, currentShowId(), reconnects, output()))).apply()
    }

    private companion object {
        const val OPEN = "analytics.openSession"
    }
}
