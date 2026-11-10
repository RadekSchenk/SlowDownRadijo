package cz.slowdownradijo.app.stats

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme

/** Everything the Statistiky page shows. */
data class StatsUi(
    val summary: StatsSummary,
    val enabled: Boolean,
    val measuring: Boolean,
    val communityUnlocked: Boolean,
    val loadFailed: Boolean,
)

/**
 * Statistiky (`StatsView.swift`): today, all time and everyone together,
 * the listener's place among listeners, the week's chart and the shows
 * listened to most, then how it is measured.
 */
@Composable
fun StatsContent(ui: StatsUi, onEnable: () -> Unit, onRetry: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    val summary = ui.summary
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.xl)) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.statsTitle), style = Theme.Typography.Heading.page.copy(lineHeight = 30.sp), color = Theme.textPrimary)
                BodyText(stringResource(R.string.statsSubtitle))
            }
            if (ui.enabled) {
                MetricCard(stringResource(R.string.today), summary.todaySeconds, stringResource(R.string.statsTodayDescription), ui.measuring)
                MetricCard(stringResource(R.string.statsTotal), summary.totalSeconds, stringResource(R.string.statsTotalDescription))
                if (ui.communityUnlocked) {
                    MetricCard(stringResource(R.string.statsCommunityTitle), summary.communitySeconds, stringResource(R.string.statsCommunityDescription))
                }
            } else {
                Column(
                    Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
                ) {
                    BodyText(stringResource(R.string.statsDisabledMessage))
                    PrimaryActionButton(stringResource(R.string.statsEnableAction), onClick = onEnable)
                }
            }
            ListDivider()
        }

        if (ui.enabled) {
            Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
                Heading(stringResource(R.string.statsLeaderboardTitle))
                val rank = summary.rank
                when {
                    !ui.communityUnlocked -> Row(
                        Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
                    ) {
                        Trophy()
                        BodyText(stringResource(R.string.statsLeaderboardLocked), Modifier.weight(1f))
                    }
                    rank != null -> {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(
                                    buildAnnotatedString {
                                        withStyle(SpanStyle(color = Theme.liveRed, fontSize = 48.sp, fontWeight = FontWeight.ExtraBold)) { append("#$rank") }
                                        withStyle(SpanStyle(color = Theme.mutedText, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)) {
                                            append(" ${stringResource(R.string.statsRankOf)} ${StatsFormat.number(english, summary.rankedListeners)}")
                                        }
                                    },
                                    style = Theme.Typography.manrope(14f, FontWeight.SemiBold).copy(lineHeight = 58.sp), maxLines = 1,
                                )
                                Text(stringResource(R.string.statsLeaderboardScope), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.lavender)
                            }
                            Trophy()
                        }
                        BodyText(stringResource(R.string.statsLeaderboardDescription, StatsFormat.number(english, summary.rankedListeners)))
                        Text(stringResource(R.string.statsEncouragement), style = Theme.Typography.Copy.link.copy(lineHeight = 20.sp), color = Theme.textPrimary)
                        if (ui.loadFailed) BodyText(stringResource(R.string.statsOfflineNote), color = Theme.subtleText)
                    }
                    ui.loadFailed -> {
                        BodyText(stringResource(R.string.statsRankFailed))
                        SecondaryActionButton(stringResource(R.string.statsRetry), onClick = onRetry)
                    }
                    summary.totalSeconds == 0 -> BodyText(stringResource(R.string.statsRankNoListening))
                    summary.totalSeconds < 60 -> BodyText(stringResource(R.string.statsRankNeedsMinute))
                    else -> BodyText(stringResource(R.string.statsRankCalculating))
                }
                ListDivider()
            }

            Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
                    Heading(stringResource(R.string.statsTimelineTitle))
                    if (summary.weekStart != null && summary.weekEnd != null) {
                        Text(StatsFormat.dateRange(english, summary.weekStart, summary.weekEnd), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.mutedText)
                    }
                    WeeklyChart(summary)
                }
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Heading(stringResource(R.string.statsShowsTitle))
                    val top = summary.shows.firstOrNull()
                    if (top != null) {
                        Text(
                            stringResource(R.string.statsShowsContext, StatsFormat.duration(english, summary.showsSeconds)),
                            style = Theme.Typography.manrope(13f, FontWeight.Normal), color = Theme.mutedText,
                        )
                        Column {
                            ShowShareRow(top, isTop = true)
                            summary.shows.drop(1).take(7).forEach {
                                ListDivider()
                                ShowShareRow(it)
                            }
                        }
                    } else {
                        BodyText(stringResource(R.string.statsEmptyShows))
                    }
                }
                ListDivider()
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Heading(stringResource(R.string.statsExplainTitle))
            BodyText(stringResource(R.string.statsExplainBody))
            Text(stringResource(R.string.statsPrivacyNote), style = Theme.Typography.manrope(12f, FontWeight.Normal), color = Theme.subtleText)
        }
    }
}

/** "Tvoje statistiky poslechu" on the home screen (`StatsHomeBlock.swift`); opens Statistiky. */
@Composable
fun StatsHomeBlock(ui: StatsUi, onOpen: () -> Unit, modifier: Modifier = Modifier) {
    val english = LocalAppLanguage.current.isEnglish
    val summary = ui.summary
    Column(modifier.fillMaxWidth().clickable(onClick = onOpen), verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
        Text(stringResource(R.string.statsHomeTitle), style = Theme.Typography.Heading.section.copy(lineHeight = 26.sp), color = Theme.textPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallMetric(stringResource(R.string.today), summary.todaySeconds, ui.measuring, Modifier.weight(1f))
            // On the first day "Celkem" would only repeat "Dnes".
            if (summary.totalSeconds >= summary.todaySeconds + 60) {
                SmallMetric(stringResource(R.string.statsTotal), summary.totalSeconds, false, Modifier.weight(1f))
            }
        }
        if (ui.communityUnlocked) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.statsLeaderboardScope), style = Theme.Typography.Copy.body, color = Theme.mutedText, maxLines = 1, modifier = Modifier.weight(1f))
                Box(Modifier.background(Theme.liveRed.copy(alpha = 0.08f), RoundedCornerShape(6.dp)).padding(horizontal = 8.dp, vertical = 4.dp)) {
                    val rank = summary.rank
                    if (rank != null) {
                        Text(
                            buildAnnotatedString {
                                withStyle(SpanStyle(color = Theme.liveRed, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold)) { append("#$rank") }
                                withStyle(SpanStyle(color = Theme.mutedText)) { append("  ${stringResource(R.string.statsRankOf)} ${StatsFormat.number(english, summary.rankedListeners)}") }
                            },
                            style = Theme.Typography.Copy.body,
                        )
                    } else {
                        Text("—", style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = Theme.mutedText)
                    }
                }
            }
        }
    }
}

@Composable
private fun SmallMetric(label: String, seconds: Int, isLive: Boolean, modifier: Modifier) {
    Column(modifier.background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(label, style = Theme.Typography.Copy.label, color = Theme.mutedText)
            AnimatedVisibility(isLive) { ListeningDot() }
        }
        DurationText(seconds, numberSize = 20f, unitSize = 13f)
    }
}

@Composable
private fun MetricCard(label: String, seconds: Int, description: String, isLive: Boolean = false) {
    Column(
        Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(label, style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.mutedText)
            AnimatedVisibility(isLive) { ListeningDot() }
        }
        DurationText(seconds, numberSize = 36f, unitSize = 19f)
        BodyText(description)
    }
}

/** "2 d 4 h 17 m" with big numbers and small units; "< 1 m" in the first minute (`DurationText`). */
@Composable
fun DurationText(seconds: Int, numberSize: Float, unitSize: Float) {
    val english = LocalAppLanguage.current.isEnglish
    val (days, hours, minutes) = StatsFormat.parts(seconds)
    val label = if (seconds in 1..59) stringResource(R.string.statsUnderAMinute) else StatsFormat.duration(english, seconds)
    val number = SpanStyle(color = Theme.textPrimary, fontSize = numberSize.sp, fontWeight = FontWeight.ExtraBold)
    val unit = SpanStyle(color = Theme.mutedText, fontSize = unitSize.sp, fontWeight = FontWeight.SemiBold)
    Text(
        buildAnnotatedString {
            if (seconds in 1..59) {
                withStyle(unit) { append("< ") }; withStyle(number) { append("1") }; withStyle(unit) { append(" m") }
            } else {
                if (days > 0) { withStyle(number) { append(StatsFormat.number(english, days)) }; withStyle(unit) { append(" d ") } }
                withStyle(number) { append("$hours") }; withStyle(unit) { append(" h ") }
                withStyle(number) { append("$minutes") }; withStyle(unit) { append(" m") }
            }
        },
        style = Theme.Typography.manrope(numberSize, FontWeight.ExtraBold).copy(fontFeatureSettings = "tnum"),
        maxLines = 1,
        modifier = Modifier.clearAndSetSemantics { contentDescription = label },
    )
}

@Composable
private fun WeeklyChart(summary: StatsSummary) {
    val english = LocalAppLanguage.current.isEnglish
    Column(Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(StatsFormat.duration(english, summary.weekSeconds), style = Theme.Typography.manrope(24f, FontWeight.ExtraBold), color = Theme.textPrimary)
            Spacer(Modifier.weight(1f))
            Text(stringResource(R.string.statsWeekCaption), style = Theme.Typography.manrope(11f, FontWeight.Normal), color = Theme.lavender)
        }
        if (summary.weekSeconds == 0) {
            Box(Modifier.fillMaxWidth().heightIn(min = 153.dp), contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.statsEmptyChart), style = Theme.Typography.manrope(14f, FontWeight.Normal), color = Theme.mutedText)
            }
        } else {
            val peak = summary.bars.maxOf { it.seconds }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
                for (bar in summary.bars) {
                    val target = if (bar.seconds > 0 && peak > 0) maxOf(2f, bar.seconds.toFloat() / peak * 105f) else 2f
                    val height by animateFloatAsState(target, label = "bar")
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(StatsFormat.compactDuration(english, bar.seconds), style = Theme.Typography.manrope(9f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
                        Box(Modifier.height(110.dp), contentAlignment = Alignment.BottomCenter) {
                            Box(
                                Modifier
                                    .width(20.dp)
                                    .height(height.dp)
                                    .alpha(if (bar.seconds > 0) 1f else 0.4f)
                                    .background(if (bar.isPeak) Theme.liveRed else Theme.statsBarMuted, RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp, bottomStart = 1.dp, bottomEnd = 1.dp))
                            )
                        }
                        Text(StatsFormat.shortDay(english, bar.weekday), style = Theme.Typography.manrope(11f, FontWeight.SemiBold), color = Theme.mutedText)
                    }
                }
            }
        }
    }
}

@Composable
private fun ShowShareRow(share: StatsSummary.ShowShare, isTop: Boolean = false) {
    val english = LocalAppLanguage.current.isEnglish
    val fraction by animateFloatAsState(share.fraction.toFloat(), label = "share")
    Column(Modifier.padding(vertical = 16.dp).semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                if (isTop) {
                    Text(
                        stringResource(R.string.statsTopShowKicker), style = Theme.Typography.manrope(11f, FontWeight.ExtraBold).copy(letterSpacing = 0.5.sp),
                        color = Theme.liveRed, modifier = Modifier.padding(bottom = 2.dp),
                    )
                }
                Text(share.name ?: stringResource(R.string.statsUnknownShow), style = Theme.Typography.manrope(if (isTop) 21f else 17f, FontWeight.ExtraBold), color = Theme.textPrimary)
                share.hostName?.let { Text(it, style = Theme.Typography.manrope(12f, FontWeight.Normal), color = Theme.mutedText) }
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(StatsFormat.duration(english, share.seconds), style = Theme.Typography.manrope(if (isTop) 17f else 15f, FontWeight.ExtraBold), color = Theme.textPrimary)
                Text(StatsFormat.percent(share.fraction), style = Theme.Typography.manrope(12f, FontWeight.Normal), color = Theme.mutedText)
            }
        }
        val barHeight = if (isTop) 5.dp else 3.dp
        Box(Modifier.fillMaxWidth().height(barHeight).background(Theme.divider, CircleShape)) {
            Box(Modifier.fillMaxWidth(fraction.coerceIn(0.02f, 1f)).height(barHeight).background(if (isTop) Theme.liveRed else Theme.mutedText, CircleShape))
        }
    }
}

@Composable
private fun Trophy() {
    Box(Modifier.size(48.dp).background(Theme.liveRed.copy(alpha = 0.1f), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
        Icon(painterResource(R.drawable.stats_trophy), null, tint = Theme.liveRed, modifier = Modifier.size(23.dp))
    }
}

/** The red dot breathing while listening time is counted (`ListeningDot`). */
@Composable
fun ListeningDot() {
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    val alpha = if (animate) rememberInfiniteTransition(label = "dot").animateFloat(0.35f, 1f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "dot").value else 1f
    val label = stringResource(R.string.statsCountingNow)
    Box(Modifier.size(6.dp).alpha(alpha).background(Theme.liveRed, CircleShape).semantics { contentDescription = label })
}

@Composable
private fun Heading(text: String) = Text(text, style = Theme.Typography.Heading.section.copy(lineHeight = 26.sp), color = Theme.textPrimary)

@Composable
private fun BodyText(text: String, modifier: Modifier = Modifier, color: androidx.compose.ui.graphics.Color = Theme.mutedText) =
    Text(text, style = Theme.Typography.manrope(14f, FontWeight.Normal).copy(lineHeight = 20.sp), color = color, modifier = modifier)
