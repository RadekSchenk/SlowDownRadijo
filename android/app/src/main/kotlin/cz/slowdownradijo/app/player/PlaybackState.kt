package cz.slowdownradijo.app.player

sealed interface PlaybackState {
    data object Idle : PlaybackState
    data object Connecting : PlaybackState
    data object Playing : PlaybackState
    data object Paused : PlaybackState
    /** The stream dropped; a reconnect is scheduled (`streamInterrupted`). */
    data object Error : PlaybackState
}

/** What last started playback, as `RadioPlayerService.PlayTrigger` (analytics names). */
enum class PlayTrigger(val analyticsName: String) {
    USER("user"), AUTOPLAY("autoplay"), LOCK_SCREEN("lock_screen"), NOTIFICATION("notification"), RESUME("resume"), PREVIEW("preview"),
    /** The live item on the car's screen, as iOS's "carplay". */
    ANDROID_AUTO("android_auto"),
}

/** What last stopped it, as `RadioPlayerService.StopReason`. */
enum class StopReason(val analyticsName: String) {
    USER("user"), SLEEP_TIMER("sleep_timer"), INTERRUPTION("interruption"), HEADPHONES("headphones"), VOICE_MESSAGE("voice_message"), PREVIEW("preview"),
}

/** Back-off between reconnects: 2, 4, 8, 16, then 30 s. */
object ReconnectPolicy {
    fun delayMillis(attempt: Int): Long = minOf(30_000L, 1000L shl attempt.coerceIn(1, 15))
}
