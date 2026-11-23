package cz.slowdownradijo.app.winter

import android.content.Context
import android.os.PowerManager
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.frameClock
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.sin

// The pieces of "Zimní vzhled", as `WinterViews.swift`.

/** The sun in `BrandLogo.png`, as fractions (as `AnimatedBrandLogo.swift`). */
private const val SUN_X = 0.378f + 0.258f / 2
private const val SUN_TOP = 0.069f

private val gold = listOf(Color(0xFFF5C75C), Color(0xFFFFE38C), Color(0xFFC7872A))

/**
 * The logo's sun as a Christmas bauble: a gold cap on the striped "O" and the
 * thread it hangs on, reaching [threadLength] above it. Lay it over the logo
 * at the logo's own size.
 */
@Composable
fun WinterBauble(modifier: Modifier, threadLength: Dp = 16.dp) {
    Canvas(modifier) {
        val centerX = SUN_X * size.width
        val sunTop = SUN_TOP * size.height
        // Figma: a 7 × 3.6 cap on the 80dp-wide header logo.
        val cap = Size(size.width * 0.0875f, size.width * 0.045f)
        val capTop = sunTop - cap.height * 0.7f
        val thread = max(0.75.dp.toPx(), size.width * 0.005f)
        val length = threadLength.toPx()
        drawRect(
            Brush.verticalGradient(listOf(Color.White.copy(alpha = 0f), Color.White.copy(alpha = 0.5f)), capTop - length, capTop),
            topLeft = Offset(centerX - thread / 2, capTop - length),
            size = Size(thread, length),
        )
        drawRoundRect(
            Brush.horizontalGradient(gold, centerX - cap.width / 2, centerX + cap.width / 2),
            topLeft = Offset(centerX - cap.width / 2, capTop),
            size = cap,
            cornerRadius = CornerRadius(cap.height * 0.25f),
        )
    }
}

/**
 * Slowly falling snow drawn behind the content, from its top down to [height],
 * thinning out towards the bottom so it never reaches the text. Still in tests
 * and with reduced motion; none in battery saver.
 */
@Composable
fun Modifier.winterSnow(enabled: Boolean, height: Dp = 340.dp, count: Int = 32): Modifier {
    if (!enabled) return this
    val power = LocalContext.current.getSystemService(Context.POWER_SERVICE) as? PowerManager
    if (power?.isPowerSaveMode == true) return this
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    val frame = frameClock(animate)
    return drawBehind {
        drawSnow(if (animate) frame.value else 0.0, height.toPx(), count)
    }
}

private fun DrawScope.drawSnow(time: Double, height: Float, count: Int) {
    val dp = density
    val span = height + 12 * dp
    for (index in 0 until count) {
        val radius = (1.1 + 2.0 * random(index, 1)).toFloat() * dp
        val speed = (8 + 14 * random(index, 2)) * dp
        var y = ((random(index, 3) * span + time * speed) % span).toFloat() - 6 * dp
        if (y < -6 * dp) y += span
        val sway = (5 + 8 * random(index, 4)) * sin(time / (3 + 4 * random(index, 5)) + 6.28 * random(index, 6))
        val x = (random(index, 7) * size.width + sway * dp).toFloat()
        val opacity = ((0.3 + 0.55 * random(index, 8)) * max(0f, 1 - y / height)).toFloat()
        if (opacity < 0.01f) continue
        drawCircle(Color(0xFFF6F4FF).copy(alpha = opacity.coerceAtMost(1f)), radius, Offset(x, y))
    }
}

/** A fixed pseudo-random number in 0..<1 per flake and property (the same formula as iOS). */
private fun random(index: Int, salt: Int): Double {
    val value = sin(index * 12.9898 + salt * 78.233) * 43_758.5453
    return value - floor(value)
}
