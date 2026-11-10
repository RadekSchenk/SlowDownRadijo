package cz.slowdownradijo.app.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import cz.slowdownradijo.app.data.SharedImages
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.RadioPulse
import cz.slowdownradijo.app.ui.components.frameClock
import cz.slowdownradijo.app.ui.components.smooth
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * The show's photo in the compact player, as `NowPlayingCover.swift`
 * (Figma "Cover s ekvalizérem"): 96 × 96 with 10 corners, flanked by the
 * waveform in a 140 × 108 box.
 */
@Composable
fun NowPlayingCover(show: Show?, isPlaying: Boolean, modifier: Modifier = Modifier) {
    Box(modifier.size(140.dp, 108.dp), contentAlignment = Alignment.Center) {
        CardSideEqualizer(isActive = isPlaying)
        val shape = RoundedCornerShape(10.dp)
        val bundled = SharedImages.drawable(show?.artworkName)
        val photo = Modifier
            .size(96.dp)
            .clip(shape)
        when {
            bundled != null -> Image(painterResource(bundled), null, photo, contentScale = ContentScale.Crop)
            show?.imageURL != null -> AsyncImage(show.imageURL, null, photo.background(Theme.brandPurple), contentScale = ContentScale.Crop)
            else -> ShowArtworkPlaceholder(photo)
        }
    }
}

/** A show without a photo (a special from the web): the brand gradient. */
@Composable
fun ShowArtworkPlaceholder(modifier: Modifier) {
    Box(modifier.background(Brush.linearGradient(listOf(Theme.brandPurple, Theme.liveRed))))
}

private class Bar(val x: Float, val peak: Float, val rest: Float, val opacity: Float, val waves: List<Triple<Double, Double, Double>>)

private const val BARS_PER_SIDE = 5
private const val BAR_WIDTH = 2f
private const val SPACING = 4.57f
private const val INSET = 1.7f
private const val COVER = 96f
private const val MAX_PEAK = 60f
private const val FALLOFF = 0.3f
private val BAR_COLOR = Color(0xFF8C839C)

/** Stable pseudo-random numbers in 0..<1, the same as on iOS. */
private fun random(seed: Double): Double {
    val value = sin(seed * 12.9898 + 78.233) * 43758.5453
    return value - floor(value)
}

private val bars: List<Bar> = buildList {
    val side = INSET + SPACING * BARS_PER_SIDE
    for (s in 0 until 2) for (index in 0 until BARS_PER_SIDE) {
        val seed = (s * 100 + index).toDouble()
        val distance = index.toDouble() / (BARS_PER_SIDE - 1)
        val envelope = 0.28 + 0.72 * (1 - distance).pow(1.15)
        val peak = (MAX_PEAK * envelope * (0.72 + 0.28 * random(seed + 0.1))).toFloat()
        val offset = INSET + SPACING * index
        val x = if (s == 0) side - offset - BAR_WIDTH else side + COVER + offset
        add(
            Bar(
                x = x,
                peak = peak,
                rest = max(BAR_WIDTH * 2, (peak * (0.22 + 0.18 * random(seed + 0.2))).toFloat()),
                opacity = 0.5f * (1 - FALLOFF * distance.toFloat()),
                waves = listOf(
                    Triple(1.1 + random(seed + 0.3) * 0.9, random(seed + 0.4) * 6.28, 0.5),
                    Triple(2.3 + random(seed + 0.5) * 1.3, random(seed + 0.6) * 6.28, 0.3),
                    Triple(3.9 + random(seed + 0.7) * 1.8, random(seed + 0.8) * 6.28, 0.2),
                ),
            )
        )
    }
}

/**
 * The waveform either side of the cover, as `CardSideEqualizer` (compact
 * style): five 2-wide bars a side growing from the middle line, each on its
 * own mix of sines, all swelling on [RadioPulse]. Play and pause ease them
 * to and from a calm, dimmer frozen wave.
 */
@Composable
fun CardSideEqualizer(isActive: Boolean, modifier: Modifier = Modifier) {
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    var changedAt by remember { mutableDoubleStateOf(Double.NEGATIVE_INFINITY) }
    var settling by remember { mutableStateOf(false) }
    val frame = frameClock(animate && (isActive || settling))
    LaunchedEffect(isActive) {
        changedAt = System.nanoTime() / 1e9
        if (!isActive) {
            settling = true
            delay(800)
            settling = false
        }
    }
    Canvas(modifier.size(140.dp, 108.dp)) {
        val time = frame.value
        val blend = if (!animate) 0.0 else {
            val eased = smooth((time - changedAt) / 0.8)
            if (isActive) eased else 1 - eased
        }
        val brightness = (0.55 + 0.45 * blend).toFloat()
        val unit = density
        for (bar in bars) {
            val height = barHeight(bar, time, blend) * unit
            drawRoundRect(
                color = BAR_COLOR.copy(alpha = bar.opacity * brightness),
                topLeft = Offset(bar.x * unit, (size.height - height) / 2),
                size = Size(BAR_WIDTH * unit, height),
                cornerRadius = CornerRadius(BAR_WIDTH * unit / 2),
            )
        }
    }
}

private fun barHeight(bar: Bar, time: Double, intensity: Double): Float {
    if (intensity <= 0) return bar.rest
    val signal = bar.waves.sumOf { (frequency, phase, weight) -> weight * sin(2 * PI * frequency * time + phase) }
    val pulse = 0.72 + 0.28 * RadioPulse.beat(time)
    val level = min(max((signal + 1) / 2 * pulse, 0.0), 1.0)
    val floor = bar.peak * 0.16f
    val moving = floor + (bar.peak - floor) * level.toFloat()
    return bar.rest + (moving - bar.rest) * intensity.toFloat()
}
