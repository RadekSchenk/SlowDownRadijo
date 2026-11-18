package cz.slowdownradijo.app

import android.content.Context
import cz.slowdownradijo.app.player.StreamQuality
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The listener's switches in Settings, with the iOS app's defaults and keys. */
class AppSettings(context: Context) {
    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    private val _autoplay = MutableStateFlow(prefs.getBoolean(AUTOPLAY, true))
    /** Start the radio when the app opens. */
    val autoplay: StateFlow<Boolean> = _autoplay.asStateFlow()

    private val _statsEnabled = MutableStateFlow(prefs.getBoolean(STATS, true))
    /** Count listening time for the listening stats. */
    val statsEnabled: StateFlow<Boolean> = _statsEnabled.asStateFlow()

    private val _streamQuality = MutableStateFlow(StreamQuality.fromId(prefs.getString(STREAM_QUALITY, null)))
    /** Which live stream plays: automatic by network, always MP3, or always AAC. */
    val streamQuality: StateFlow<StreamQuality> = _streamQuality.asStateFlow()

    fun setAutoplay(on: Boolean) {
        prefs.edit().putBoolean(AUTOPLAY, on).apply()
        _autoplay.value = on
    }

    fun setStatsEnabled(on: Boolean) {
        prefs.edit().putBoolean(STATS, on).apply()
        _statsEnabled.value = on
    }

    fun setStreamQuality(quality: StreamQuality) {
        prefs.edit().putString(STREAM_QUALITY, quality.id).apply()
        _streamQuality.value = quality
    }

    private companion object {
        const val AUTOPLAY = "autoplayEnabled"
        const val STATS = "statsEnabled"
        const val STREAM_QUALITY = "streamQuality"
    }
}
