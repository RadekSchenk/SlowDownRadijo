package cz.slowdownradijo.app

import android.content.Context
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

    fun setAutoplay(on: Boolean) {
        prefs.edit().putBoolean(AUTOPLAY, on).apply()
        _autoplay.value = on
    }

    fun setStatsEnabled(on: Boolean) {
        prefs.edit().putBoolean(STATS, on).apply()
        _statsEnabled.value = on
    }

    private companion object {
        const val AUTOPLAY = "autoplayEnabled"
        const val STATS = "statsEnabled"
    }
}
