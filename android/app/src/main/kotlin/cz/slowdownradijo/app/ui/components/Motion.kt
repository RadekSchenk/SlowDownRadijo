package cz.slowdownradijo.app.ui.components

import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.platform.LocalContext
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin

/**
 * The shared beat of the home screen's motion: the bars by the cover and
 * the clouds swell on it together, about 114 times a minute (`RadioPulse`).
 */
object RadioPulse {
    const val BEATS_PER_SECOND = 1.9
    fun beat(time: Double): Double = max(0.0, sin(2 * PI * BEATS_PER_SECOND * time)).pow(2)
}

/** Android's "Remove animations" stands in for iOS Reduce Motion. */
val LocalReduceMotion = staticCompositionLocalOf { false }

/** False in tests and previews: everything draws its still frame. */
val LocalAnimationsEnabled = staticCompositionLocalOf { true }

@Composable
fun systemReducesMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}

/** Seconds since the composable appeared, advancing with every frame while [running]. */
@Composable
fun frameClock(running: Boolean): State<Double> {
    val time = remember { mutableDoubleStateOf(System.nanoTime() / 1e9) }
    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        while (true) {
            withFrameNanos { time.doubleValue = it / 1e9 }
        }
    }
    return time
}

/** smoothstep */
fun smooth(u: Double): Double {
    val x = u.coerceIn(0.0, 1.0)
    return x * x * (3 - 2 * x)
}
