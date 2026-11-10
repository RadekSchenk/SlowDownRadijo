package cz.slowdownradijo.app.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.PauseIcon
import cz.slowdownradijo.app.ui.components.PlayIcon
import cz.slowdownradijo.app.ui.theme.Theme

/**
 * How far the show on air has got, as `ShowProgressBar.swift`: start and
 * end times, then a 6-high track with the `liveRed` fill and, while the
 * radio plays, a soft glow breathing at its head.
 */
@Composable
fun ShowProgressBar(show: Show, progress: Double, isPlaying: Boolean, modifier: Modifier = Modifier) {
    val style = Theme.Typography.manrope(13f, FontWeight.Bold)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row {
            Text(show.start, style = style, color = Theme.mutedText)
            Spacer(Modifier.weight(1f))
            Text(show.end, style = style, color = Theme.textPrimary)
        }
        val animated by animateFloatAsState(progress.toFloat(), tween(600), label = "progress")
        val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
        val glow = if (isPlaying && animate) {
            rememberInfiniteTransition(label = "glow").animateFloat(
                0.35f, 0.9f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "glow",
            ).value
        } else if (isPlaying) 0.9f else 0f
        Canvas(
            Modifier
                .fillMaxWidth()
                .height(6.dp)
        ) {
            val radius = CornerRadius(3.dp.toPx())
            drawRoundRect(Theme.hairline(0.1f), cornerRadius = radius)
            val fill = maxOf(size.height, size.width * animated)
            drawRoundRect(Theme.liveRed, size = Size(fill, size.height), cornerRadius = radius)
            if (glow > 0f) {
                val r = 8.dp.toPx()
                drawCircle(
                    Brush.radialGradient(
                        listOf(Theme.liveRed.copy(alpha = glow), Theme.liveRed.copy(alpha = 0f)),
                        center = Offset(fill - 3.dp.toPx(), size.height / 2), radius = r,
                    ),
                    radius = r, center = Offset(fill - 3.dp.toPx(), size.height / 2),
                )
            }
        }
    }
}

/** A flat `liveRed` circle with play, pause, or a spinner while connecting (`PlayButton.swift`). */
@Composable
fun PlayButton(state: PlaybackState, onClick: () -> Unit, diameter: Int = 46, iconSize: Int = 17) {
    val haptics = LocalHapticFeedback.current
    val label = stringResource(
        when (state) {
            PlaybackState.Connecting -> R.string.connecting
            PlaybackState.Playing -> R.string.pauseRadio
            else -> R.string.playRadio
        }
    )
    Box(
        Modifier
            .size(diameter.dp)
            .clip(CircleShape)
            .background(Theme.liveRed)
            .clickable(enabled = state != PlaybackState.Connecting) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onClick()
            }
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        when (state) {
            PlaybackState.Connecting -> CircularProgressIndicator(
                Modifier.size((iconSize + 3).dp), color = Theme.textPrimary, strokeWidth = 2.dp,
            )
            PlaybackState.Playing -> PauseIcon(iconSize.dp, Theme.textPrimary)
            else -> PlayIcon(iconSize.dp, Theme.textPrimary, Modifier.padding(start = 2.dp))
        }
    }
}
