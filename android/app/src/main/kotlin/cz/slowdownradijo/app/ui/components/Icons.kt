package cz.slowdownradijo.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** SF Symbols' play.fill, drawn: a rounded triangle. */
@Composable
fun PlayIcon(size: Dp, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        val w = this.size.width
        val h = this.size.height
        val path = Path().apply {
            moveTo(w * 0.14f, h * 0.06f)
            lineTo(w * 0.94f, h * 0.5f)
            lineTo(w * 0.14f, h * 0.94f)
            close()
        }
        drawPath(path, color)
    }
}

/** pause.fill: two rounded bars. */
@Composable
fun PauseIcon(size: Dp, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        val w = this.size.width
        val h = this.size.height
        val bar = w * 0.3f
        val radius = CornerRadius(bar * 0.3f)
        drawRoundRect(color, Offset(w * 0.12f, 0f), Size(bar, h), radius)
        drawRoundRect(color, Offset(w * 0.88f - bar, 0f), Size(bar, h), radius)
    }
}

/** moon.fill: a crescent. */
@Composable
fun MoonIcon(size: Dp, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        val w = this.size.width
        val disc = Path().apply { addOval(androidx.compose.ui.geometry.Rect(0f, 0f, w, w)) }
        val bite = Path().apply { addOval(androidx.compose.ui.geometry.Rect(w * 0.38f, -w * 0.18f, w * 1.18f, w * 0.62f)) }
        drawPath(Path.combine(PathOperation.Difference, disc, bite), color)
    }
}

/** The menu's three bars, 14 × 2 with 2 between. */
@Composable
fun Hamburger(color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        repeat(3) {
            Box(
                Modifier
                    .width(14.dp)
                    .height(2.dp)
                    .background(color, RoundedCornerShape(1.dp))
            )
        }
    }
}
