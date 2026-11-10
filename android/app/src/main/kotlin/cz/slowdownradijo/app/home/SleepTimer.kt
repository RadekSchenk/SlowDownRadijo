package cz.slowdownradijo.app.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.MoonIcon
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** The sleep timer's choices, as `SleepTimerOption` on iOS. */
enum class SleepTimerOption(val minutes: Int?, val analyticsName: String) {
    MIN5(5, "5m"), MIN10(10, "10m"), MIN15(15, "15m"), MIN30(30, "30m"), MIN45(45, "45m"), HOUR1(60, "60m"), END_OF_SHOW(null, "end_of_show");

    val duration: Duration? get() = minutes?.let { Duration.ofMinutes(it.toLong()) }
    val tileValue: String get() = if (this == HOUR1) "1" else minutes?.toString() ?: ""

    companion object {
        val durations = listOf(MIN5, MIN10, MIN15, MIN30, MIN45, HOUR1)
    }
}

/** "9 min 56 s": whole seconds, rounded up so it never reads "0 s" while playing. */
fun sleepRemainingLabel(english: Boolean, fireAt: Instant, now: Instant): String {
    val millis = Duration.between(now, fireAt).toMillis()
    val seconds = maxOf(0L, (millis + 999) / 1000).toInt()
    return L10nLogic.countdown(english, seconds / 3600, seconds % 3600 / 60, seconds % 60)
}

/** A clock time in the app's language, in the phone's time zone. */
fun shortTime(english: Boolean, at: Instant): String =
    at.atZone(ZoneId.systemDefault()).format(
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(if (english) java.util.Locale.US else java.util.Locale.forLanguageTag("cs-CZ"))
    )

/**
 * The link under the progress bar: "Nastavit časovač vypnutí" and the moon,
 * or while a timer runs, the time left to the second.
 */
@Composable
fun SleepTimerLink(fireAt: Instant?, now: Instant, onClick: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    Row(
        Modifier.clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val text = if (fireAt != null) {
            stringResource(R.string.turnsOffIn, sleepRemainingLabel(english, fireAt, now))
        } else {
            stringResource(R.string.setSleepTimer)
        }
        Text(text, style = Theme.Typography.Copy.link.tabular(), color = Theme.textPrimary)
        MoonIcon(13.dp, Theme.textPrimary)
    }
}

/**
 * The sleep-timer picker, as `SleepTimerSheet`: duration tiles, "Konec
 * pořadu" with the show's end time, and while a timer runs the countdown
 * and a cancel button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SleepTimerSheet(
    activeOption: SleepTimerOption?,
    fireAt: Instant?,
    showEnd: Instant?,
    now: Instant,
    onSelect: (SleepTimerOption) -> Unit,
    onCancel: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        SleepTimerSheetContent(activeOption, fireAt, showEnd, now, onSelect, onCancel)
    }
}

@Composable
fun SleepTimerSheetContent(
    activeOption: SleepTimerOption?,
    fireAt: Instant?,
    showEnd: Instant?,
    now: Instant,
    onSelect: (SleepTimerOption) -> Unit,
    onCancel: () -> Unit,
) {
    val english = LocalAppLanguage.current.isEnglish
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = 16.dp)
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.sleepTimerSheetTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
                if (fireAt != null) {
                    Text(
                        stringResource(R.string.turnsOffIn, sleepRemainingLabel(english, fireAt, now)),
                        style = Theme.Typography.Copy.body.tabular(), color = Theme.liveRed,
                    )
                } else {
                    Text(stringResource(R.string.sleepTimerHint), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                }
            }
            SleepMoon(isOn = fireAt != null)
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SleepTimerOption.durations.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { option ->
                        DurationTile(option, isActive = option == activeOption && fireAt != null, Modifier.weight(1f)) { onSelect(option) }
                    }
                }
            }
            val endActive = activeOption == SleepTimerOption.END_OF_SHOW && fireAt != null
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (endActive) Theme.liveRed else Theme.statsCardRaised)
                    .clickable(enabled = showEnd != null) { onSelect(SleepTimerOption.END_OF_SHOW) }
                    .alpha(if (showEnd != null) 1f else 0.4f)
                    .padding(horizontal = 16.dp)
                    .semantics { selected = endActive },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.endOfShow), style = Theme.Typography.Copy.button, color = Theme.textPrimary)
                Spacer(Modifier.weight(1f))
                if (showEnd != null) {
                    Text(
                        stringResource(R.string.atTime, shortTime(english, showEnd)),
                        style = Theme.Typography.Copy.body,
                        color = if (endActive) Theme.textPrimary else Theme.mutedText,
                    )
                }
            }
        }

        if (fireAt != null) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(Theme.Radius.button))
                    .background(Theme.hairline(0.08f))
                    .clickable(onClick = onCancel),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(R.string.cancelTimer), style = Theme.Typography.Copy.button, color = Theme.textPrimary)
            }
        }
    }
}

@Composable
private fun DurationTile(option: SleepTimerOption, isActive: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val label = if (option == SleepTimerOption.HOUR1) stringResource(R.string.oneHour) else stringResource(R.string.minutesOption, option.minutes ?: 0)
    Column(
        modifier
            .height(72.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(if (isActive) Theme.liveRed else Theme.statsCardRaised)
            .clickable(onClick = onClick)
            .semantics { contentDescription = label; selected = isActive },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(option.tileValue, style = Theme.Typography.manrope(28f, FontWeight.ExtraBold), color = Theme.textPrimary)
        Text(
            stringResource(if (option == SleepTimerOption.HOUR1) R.string.hoursUnit else R.string.minutesUnit),
            style = Theme.Typography.manrope(12f, FontWeight.SemiBold),
            color = if (isActive) Theme.textPrimary else Theme.mutedText,
        )
    }
}

private val moonColor = Color(0xFFD6CCFF)
private val haloColor = Color(0xFF9C8CFF)

private class Star(val x: Float, val y: Float, val size: Float, val sparkle: Boolean, val duration: Int, val delay: Int)

private val stars = listOf(
    Star(14f, 16f, 9f, true, 2200, 0), Star(30f, 46f, 3f, false, 1700, 600), Star(6f, 38f, 2.5f, false, 2600, 1100),
    Star(40f, 8f, 2.5f, false, 1900, 300), Star(86f, 10f, 11f, true, 2800, 900), Star(98f, 34f, 3f, false, 2100, 200),
    Star(80f, 54f, 7f, true, 2400, 1400), Star(102f, 58f, 2.5f, false, 1600, 800), Star(22f, 60f, 2f, false, 2900, 1700),
)

/** The night sky by the sheet's title (`SleepMoon.swift`): a glowing moon among twinkling stars. */
@Composable
fun SleepMoon(isOn: Boolean) {
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    val transition = rememberInfiniteTransition(label = "stars")
    val twinkles = stars.map { star ->
        if (animate) transition.animateFloat(
            0.25f, 1f, infiniteRepeatable(tween(star.duration, delayMillis = star.delay), RepeatMode.Reverse), label = "star",
        ).value else 0.8f
    }
    Canvas(Modifier.size(108.dp, 68.dp)) {
        val u = density
        val center = Offset(54 * u, 34 * u)
        drawCircle(
            Brush.radialGradient(listOf(haloColor.copy(alpha = if (isOn) 0.55f else 0.4f), Color.Transparent), center, 34 * u),
            radius = 34 * u, center = center,
        )
        val r = 16 * u
        val disc = Path().apply { addOval(androidx.compose.ui.geometry.Rect(center, r)) }
        val bite = Path().apply { addOval(androidx.compose.ui.geometry.Rect(Offset(center.x + r * 0.55f, center.y - r * 0.45f), r * 0.9f)) }
        drawPath(Path.combine(PathOperation.Difference, disc, bite), moonColor)
        stars.forEachIndexed { i, star ->
            val c = Offset(star.x * u, star.y * u)
            val alpha = twinkles[i]
            if (star.sparkle) {
                val s = star.size * u / 2
                val path = Path().apply {
                    moveTo(c.x, c.y - s); quadraticTo(c.x, c.y, c.x + s, c.y)
                    quadraticTo(c.x, c.y, c.x, c.y + s); quadraticTo(c.x, c.y, c.x - s, c.y)
                    quadraticTo(c.x, c.y, c.x, c.y - s); close()
                }
                drawPath(path, moonColor.copy(alpha = alpha))
            } else {
                drawCircle(Color.White.copy(alpha = alpha), radius = star.size * u / 2, center = c)
            }
        }
    }
}

/** Tabular digits, so a countdown doesn't twitch in width every second. */
fun androidx.compose.ui.text.TextStyle.tabular() = copy(fontFeatureSettings = "tnum")
