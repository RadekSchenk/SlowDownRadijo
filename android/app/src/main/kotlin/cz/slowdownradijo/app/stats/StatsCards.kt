package cz.slowdownradijo.app.stats

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.theme.Theme

/** The pale pink of labels on the coloured cards (`Color.glowLabel`). */
val GlowLabel = Color(0xFFFFD0D5)

enum class GlowStyle { STATS, MEMBER }

/**
 * The coloured lead card of Statistiky (S1) and Profil (M15), as `GlowCard`
 * in StatsCards.swift: Statistiky violet with the glow top right, the
 * Slowrider card darker wine with the glow bottom left.
 */
@Composable
fun GlowCard(style: GlowStyle = GlowStyle.STATS, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val member = style == GlowStyle.MEMBER
    val radius = if (member) 24.dp else 22.dp
    val shape = RoundedCornerShape(radius)
    val colors = if (member) listOf(Color(0xFF150F28), Color(0xFF221437), Color(0xFF3A1430))
    else listOf(Color(0xFF4A2A86), Color(0xFF2A1D52), Color(0xFF1A1535))
    var size by remember { mutableStateOf(IntSize.Zero) }
    Box(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                Brush.linearGradient(
                    colors,
                    start = if (member) Offset(size.width.toFloat(), 0f) else Offset.Zero,
                    end = if (member) Offset(0f, size.height.toFloat()) else Offset(size.width.toFloat(), size.height.toFloat()),
                )
            )
            .border(1.dp, Color.White.copy(alpha = if (member) 0.14f else 0.10f), shape)
            .onSizeChanged { size = it },
    ) {
        // A soft radial glow (a blur needs Android 12+); top right on Statistiky, bottom left on the Slowrider card.
        Canvas(Modifier.matchParentSize()) {
            val r = 150.dp.toPx()
            val c = if (member) Offset(10.dp.toPx(), size.height + 10.dp.toPx()) else Offset(size.width - 30.dp.toPx(), 10.dp.toPx())
            drawCircle(
                Brush.radialGradient(listOf(Color(0xFFFF3B4E).copy(alpha = if (member) 0.38f else 0.42f), Color.Transparent), center = c, radius = r),
                radius = r, center = c,
            )
        }
        Column(Modifier.fillMaxWidth().padding(if (member) 22.dp else 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp), content = content)
    }
}

/** A plain dark card (`StatsPanel`). */
@Composable
fun StatsPanel(spacing: Int = 14, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(20.dp)).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(spacing.dp),
        content = content,
    )
}

/** The last seven days inside a coloured card: hours above, the busiest day red, today "Dnes" (`WeekBars`). */
@Composable
fun WeekBars(bars: List<StatsSummary.DayBar>) {
    val english = LocalAppLanguage.current.isEnglish
    val peak = bars.maxOfOrNull { it.seconds } ?: 0
    val label = bars.joinToString(", ") { "${StatsFormat.shortDay(english, it.weekday)} ${StatsFormat.duration(english, it.seconds)}" }
    Row(Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = label }, horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
        bars.forEachIndexed { index, bar ->
            val today = index == bars.lastIndex
            val target = if (bar.seconds > 0 && peak > 0) maxOf(6f, bar.seconds.toFloat() / peak * 62f) else 4f
            val height by animateFloatAsState(target, label = "bar")
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    StatsFormat.compactDuration(english, bar.seconds), style = Theme.Typography.manrope(10f, FontWeight.Bold),
                    color = if (bar.isPeak) Theme.textPrimary else Theme.mutedText, maxLines = 1,
                )
                Box(Modifier.fillMaxWidth().height(height.dp).background(if (bar.isPeak) Theme.liveRed else Color.White.copy(alpha = 0.22f), RoundedCornerShape(5.dp)))
                Text(
                    if (today) stringResource(R.string.today) else StatsFormat.shortDay(english, bar.weekday),
                    style = Theme.Typography.manrope(11f, FontWeight.Bold), color = if (today) Theme.textPrimary else Theme.mutedText, maxLines = 1,
                )
            }
        }
    }
}

data class StripItem(val value: String, val label: String, val accent: Boolean = false)

/** Three numbers side by side with hairlines between them (`StatStrip`). */
@Composable
fun StatStrip(items: List<StripItem>) {
    Row(
        Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(18.dp)).padding(vertical = 16.dp, horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEachIndexed { index, item ->
            if (index > 0) Box(Modifier.width(1.dp).height(36.dp).background(Color.White.copy(alpha = 0.10f)))
            Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(item.value, style = Theme.Typography.manrope(24f, FontWeight.ExtraBold), color = if (item.accent) Theme.liveRed else Theme.textPrimary, maxLines = 1)
                Text(item.label, style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
            }
        }
    }
}

/** A thin share bar; the leader's in the station red (`ShareBar`). */
@Composable
fun ShareBar(fraction: Double, accent: Boolean = false, height: Int = 6) {
    val value by animateFloatAsState(fraction.toFloat().coerceIn(0f, 1f), label = "share")
    Box(Modifier.fillMaxWidth().height(height.dp).background(Color.White.copy(alpha = 0.08f), CircleShape)) {
        Box(Modifier.fillMaxWidth(value.coerceAtLeast(0.02f)).height(height.dp).background(if (accent) Theme.liveRed else Theme.mutedText.copy(alpha = 0.6f), CircleShape))
    }
}

/** One show: name, host, time and a bar relative to the most listened (`ShowBarRow`). */
@Composable
fun ShowBarRow(name: String, host: String?, seconds: Int, fraction: Double, rank: Int? = null, leader: Boolean = false) {
    val english = LocalAppLanguage.current.isEnglish
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        if (rank != null) {
            Text(
                "$rank", style = Theme.Typography.manrope(if (rank == 1) 32f else 24f, FontWeight.ExtraBold),
                color = if (rank == 1) Theme.liveRed else Theme.mutedText, modifier = Modifier.width(26.dp),
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(name, style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (rank == null && host != null) Text(host, style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
                }
                Text(StatsFormat.duration(english, seconds), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = if (leader) Theme.textPrimary else Theme.mutedText)
            }
            ShareBar(fraction, accent = leader)
        }
    }
}

/**
 * The places around the listener (S1): the place just above, the listener, the place
 * just below, spaced by listening time. Neighbours, not rivals: no gaps to close
 * (`NeighboursTrack`).
 */
@Composable
fun NeighboursTrack(mine: Int, rank: Int, ahead: Int?, behind: Int?) {
    val english = LocalAppLanguage.current.isEnglish
    val values = listOfNotNull(behind, mine, ahead)
    val lo = (values.minOrNull() ?: mine).toDouble()
    val hi = (values.maxOrNull() ?: mine).toDouble()
    val span = maxOf(hi - lo, 1.0)
    val you = stringResource(R.string.statsYou)
    val label = stringResource(R.string.statsNeighbours)
    BoxWithConstraints(Modifier.fillMaxWidth().height(90.dp).clearAndSetSemantics { contentDescription = label }) {
        val width = maxWidth
        fun x(value: Int) = if (values.size < 2) width / 2 else 10.dp + (width - 20.dp) * ((value - lo) / span).toFloat()
        Canvas(Modifier.fillMaxWidth().height(4.dp).offset(y = 37.dp).clip(CircleShape)) {
            drawRect(Brush.horizontalGradient(listOf(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.22f))))
        }
        @Composable
        fun centered(xPos: androidx.compose.ui.unit.Dp, y: androidx.compose.ui.unit.Dp, half: androidx.compose.ui.unit.Dp, content: @Composable () -> Unit) {
            val clamped = xPos.coerceIn(half, width - half)
            Box(Modifier.offset(x = clamped - half, y = y).width(half * 2).wrapContentSize(Alignment.TopCenter)) { content() }
        }
        listOfNotNull(behind?.let { "#${rank + 1}" to it }, ahead?.let { "#${rank - 1}" to it }).forEach { (place, time) ->
            Box(Modifier.offset(x = x(time) - 6.dp, y = 33.dp).size(12.dp).background(Color(0xFF6F6694), CircleShape).border(2.dp, Theme.statsCardRaised, CircleShape))
            centered(x(time), 56.dp, 40.dp) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(place, style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.mutedText)
                    Text(StatsFormat.duration(english, time), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
                }
            }
        }
        centered(x(mine), 2.dp, 70.dp) {
            Text("$you · ${StatsFormat.duration(english, mine)}", style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1)
        }
        Box(Modifier.offset(x = x(mine) - 9.dp, y = 30.dp).size(18.dp).background(Theme.liveRed, CircleShape).border(3.dp, Color.White, CircleShape))
    }
}

/** "TOP 1 %" (`StatsTier`). */
object StatsTier {
    fun label(rank: Int, total: Int): String? {
        if (total <= 0 || rank < 1) return null
        if (rank <= 10 && total > 20) return "10"
        val share = rank.toDouble() / total
        return listOf(0.01, 0.05, 0.10, 0.25, 0.5).firstOrNull { share <= it }?.let { "${(it * 100).toInt()} %" }
    }

    fun isLoyal(rank: Int, total: Int) = total > 0 && rank.toDouble() / total <= 0.10
}
