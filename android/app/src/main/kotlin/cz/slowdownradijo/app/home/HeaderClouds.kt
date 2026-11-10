package cz.slowdownradijo.app.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.RadioPulse
import cz.slowdownradijo.app.ui.components.frameClock
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The coloured clouds behind the home header, as `HeaderClouds.swift`
 * (Figma "Hrající mrak — rádio"): five soft blobs in the station's reds and
 * violets that drift like smoke while the radio plays, swell on the
 * equalizer's beat, and glide to a stop (a little dimmer) on pause.
 *
 * Drawn behind the modified content, from [TOP] above it. The blur is a
 * radial fade on each lobe, which looks the same and works on every
 * Android version (RenderEffect blur needs Android 12).
 */
@Composable
fun Modifier.headerClouds(isPlaying: Boolean): Modifier {
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    var clock by remember { mutableStateOf(DriftClock(isPlaying)) }
    var settling by remember { mutableStateOf(false) }
    val running = animate && (isPlaying || settling)
    val frame = frameClock(running)
    LaunchedEffect(isPlaying) {
        val at = System.nanoTime() / 1e9
        if (clock.target != (if (isPlaying) 1.0 else 0.0)) clock = clock.set(isPlaying, at)
        if (!isPlaying) {
            settling = true
            delay((DriftClock.RAMP * 1000).toLong())
            settling = false
        }
    }
    return this.drawBehind {
        if (!animate) {
            drawClouds(time = null, energy = if (isPlaying) 1.0 else 0.0, beat = 0.0)
        } else {
            val t = frame.value
            drawClouds(time = clock.time(t), energy = clock.speed(t), beat = RadioPulse.beat(t))
        }
    }
}

private class Blob(
    val x: Float, val y: Float, val w: Float, val h: Float,
    val color: Color, val opacity: Double, val blur: Float,
    val px: Double, val py: Double, val pStretch: Double, val pGlow: Double,
    val phase: Double, val beat: Double,
)

// Figma's clouds in its 390-wide frame, stretched down behind the show.
private val blobs = listOf(
    Blob(-60f, -1f, 280f, 338f, Color(0xFFC4183A), 0.38, 40f, 23.0, 17.0, 29.0, 19.0, 0.0, 0.035),
    Blob(180f, -40f, 240f, 286f, Color(0xFF6B3FA0), 0.32, 35f, 27.0, 19.0, 21.0, 23.0, 1.7, 0.03),
    Blob(60f, 90f, 200f, 234f, Color(0xFFE0206A), 0.22, 30f, 19.0, 23.0, 17.0, 29.0, 3.1, 0.05),
    Blob(230f, 194f, 180f, 234f, Color(0xFF3B1F7A), 0.28, 25f, 31.0, 21.0, 25.0, 17.0, 4.4, 0.025),
    Blob(-20f, 246f, 160f, 208f, Color(0xFF9B7FD4), 0.14, 27.5f, 21.0, 29.0, 19.0, 27.0, 5.6, 0.04),
)

private const val DESIGN_WIDTH = 390f
/** Figma's frame starts 30 above the screen. */
private const val TOP = -30f
private const val TEMPO = 1.35

/** Smooth, never-repeating motion in about -1…1 (periods 1 : φ : √5). */
private fun wander(time: Double, period: Double, seed: Double): Double {
    val a = sin(2 * PI * time / period + seed)
    val b = sin(2 * PI * time / (period * 1.618034) + seed * 1.7)
    val c = sin(2 * PI * time / (period * 2.236068) + seed * 2.3)
    return 0.55 * a + 0.3 * b + 0.15 * c
}

/** [time] null draws them still, as in Figma. */
private fun DrawScope.drawClouds(time: Double?, energy: Double, beat: Double) {
    val dp = density
    val scale = size.width / (DESIGN_WIDTH * dp)
    val drift = if (time == null) 0.0 else 1.0
    val t = (time ?: 0.0) * TEMPO
    blobs.forEachIndexed { index, blob ->
        val seed = index * 7.31 + blob.phase
        val dx = drift * 110 * wander(t, blob.px, seed)
        val dy = drift * (-6 + 55 * wander(t, blob.py, seed + 3.7))
        val stretch = drift * 0.26 * wander(t, blob.pStretch, seed + 9.1)
        val turn = drift * 0.7 * wander(t, blob.pStretch * 1.7, seed + 5.3)
        val glow = 1 + drift * 0.22 * wander(t, blob.pGlow, seed + 2.2) + 2 * blob.beat * beat * energy
        val swell = 1 + blob.beat * beat * energy
        val opacity = (blob.opacity * glow * (0.72 + 0.28 * energy)).coerceIn(0.0, 1.0)

        val cx = ((blob.x + blob.w / 2 + dx) * scale * dp).toFloat()
        val cy = ((blob.y + blob.h / 2 + dy + TOP) * dp).toFloat()
        val cw = (blob.w * scale * (1 + stretch) * swell * dp).toFloat()
        val ch = (blob.h * (1 - stretch * 0.8) * swell * dp).toFloat()

        translate(cx, cy) {
            rotateRad(turn.toFloat(), pivot = Offset.Zero) {
                // Three overlapping lobes sliding against each other, so the
                // cloud's outline morphs like smoke.
                for (lobe in 0 until 3) {
                    val lobeSeed = seed + lobe * 11.7
                    val reach = if (lobe == 0) 0.0 else drift * 0.28
                    val ox = (reach * cw * wander(t, blob.py * 0.8, lobeSeed)).toFloat()
                    val oy = (reach * ch * wander(t, blob.px * 0.9, lobeSeed + 1.9)).toFloat()
                    val shrink = if (lobe == 0) 1.0 else 0.62 + drift * 0.1 * wander(t, blob.pGlow, lobeSeed + 4.4)
                    softEllipse(
                        center = Offset(ox, oy),
                        width = (cw * shrink).toFloat(),
                        height = (ch * shrink).toFloat(),
                        blur = blob.blur * dp,
                        color = blob.color.copy(alpha = opacity.toFloat()),
                    )
                }
            }
        }
    }
}

/** An ellipse blurred by about [blur]: a radial fade, squashed to the ellipse's shape. */
private fun DrawScope.softEllipse(center: Offset, width: Float, height: Float, blur: Float, color: Color) {
    val radius = width / 2 + blur * 2
    val core = max(0f, (width / 2 - blur * 2) / radius)
    val mid = min(1f, (width / 2) / radius)
    val brush = Brush.radialGradient(
        0f to color,
        core to color,
        mid to color.copy(alpha = color.alpha * 0.5f),
        1f to color.copy(alpha = 0f),
        center = Offset.Zero,
        radius = radius,
    )
    translate(center.x, center.y) {
        scale(scaleX = 1f, scaleY = height / width, pivot = Offset.Zero) {
            drawCircle(brush, radius = radius, center = Offset.Zero)
        }
    }
}

/**
 * Time that runs only while the radio plays, easing up from a stop and
 * down to one over [RAMP] seconds, so the clouds glide rather than jump.
 */
private data class DriftClock(
    val anchorTime: Double = 0.0,
    val anchorSpeed: Double = 0.0,
    val target: Double = 0.0,
    val anchorAt: Double = 0.0,
) {
    constructor(running: Boolean) : this(anchorSpeed = if (running) 1.0 else 0.0, target = if (running) 1.0 else 0.0, anchorAt = System.nanoTime() / 1e9)

    fun set(running: Boolean, at: Double) =
        DriftClock(time(at), speed(at), if (running) 1.0 else 0.0, at)

    fun speed(at: Double): Double {
        val u = ((at - anchorAt) / RAMP).coerceIn(0.0, 1.0)
        return anchorSpeed + (target - anchorSpeed) * (u * u * (3 - 2 * u))
    }

    /** The integral of [speed] (smoothstep's integral is u³ − u⁴/2). */
    fun time(at: Double): Double {
        val elapsed = max(0.0, at - anchorAt)
        val ramped = min(elapsed, RAMP)
        val u = ramped / RAMP
        val during = anchorSpeed * ramped + (target - anchorSpeed) * RAMP * (u * u * u - u * u * u * u / 2)
        return anchorTime + during + target * max(0.0, elapsed - RAMP)
    }

    companion object {
        const val RAMP = 1.6
    }
}
