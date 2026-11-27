package cz.slowdownradijo.app.stats

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
import cz.slowdownradijo.app.l10n.L10nLogic
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
 * Statistiky (`StatsView.swift`, Figma S1): today with the week in the coloured card,
 * total / place / days, the leaderboard around the listener (anonymous, no race), time
 * per show, everyone together, then how it is measured.
 */
@Composable
fun StatsContent(ui: StatsUi, onEnable: () -> Unit, onRetry: () -> Unit, onPeriodChanged: (StatsPeriod, ranked: Boolean) -> Unit = { _, _ -> }) {
    val english = LocalAppLanguage.current.isEnglish
    val summary = ui.summary
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 8.dp)) {
            Text(stringResource(R.string.statsTitle), style = Theme.Typography.Heading.page.copy(lineHeight = 30.sp), color = Theme.textPrimary)
            BodyText(stringResource(R.string.statsSubtitle))
        }
        if (!ui.enabled) {
            Column(
                Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
            ) {
                BodyText(stringResource(R.string.statsDisabledMessage))
                PrimaryActionButton(stringResource(R.string.statsEnableAction), onClick = onEnable)
            }
        } else {
            // Figma S1: today with the week in the coloured card.
            GlowCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.today), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = GlowLabel, modifier = Modifier.weight(1f))
                    AnimatedVisibility(ui.measuring) {
                        Row(
                            Modifier.background(Color.White.copy(alpha = 0.12f), CircleShape).padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            ListeningDot()
                            Text(stringResource(R.string.statsLiveBadge), style = Theme.Typography.manrope(11f, FontWeight.Bold).copy(letterSpacing = 1.1.sp), color = GlowLabel)
                        }
                    }
                }
                DurationText(summary.todaySeconds, numberSize = 56f, unitSize = 22f)
                Text(stringResource(R.string.statsWeekTotal, StatsFormat.duration(english, summary.weekSeconds)), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText)
                Box(Modifier.padding(top = 4.dp)) { WeekBars(summary.bars) }
            }
            val hours = summary.totalSeconds / 3600
            // This week's place and the run of days (Statistiky 1.4): both a newcomer can top.
            val rankText = if (ui.communityUnlocked) summary.period(StatsPeriod.WEEK).rank?.let { "#$it" } else null
            StatStrip(
                listOf(
                    StripItem(if (hours > 0) "${StatsFormat.number(english, hours)} h" else StatsFormat.duration(english, summary.totalSeconds), stringResource(R.string.statsStripTotal)),
                    StripItem(rankText ?: "–", stringResource(R.string.statsPeriodWeekLabel), accent = rankText != null),
                    StripItem("${summary.streakDays} ${L10nLogic.slowrideDays(english, summary.streakDays)}", stringResource(R.string.statsStripStreak)),
                )
            )
            LastWeekCard(summary)
            Leaderboard(ui, onRetry, onPeriodChanged)

            StatsPanel(spacing = 16) {
                Text(stringResource(R.string.statsShowsTitle), style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary)
                val top = summary.shows.firstOrNull()
                if (top != null) {
                    summary.shows.take(8).forEach { share ->
                        ShowBarRow(
                            share.name ?: stringResource(R.string.statsUnknownShow), share.hostName, share.seconds,
                            share.seconds.toDouble() / maxOf(top.seconds, 1), leader = share.id == top.id,
                        )
                    }
                } else {
                    BodyText(stringResource(R.string.statsEmptyShows))
                }
            }

            if (ui.communityUnlocked) {
                StatsPanel(spacing = 4) {
                    Text(stringResource(R.string.statsCommunityTitle), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText)
                    DurationText(summary.communitySeconds, numberSize = 30f, unitSize = 16f)
                    BodyText(stringResource(R.string.statsCommunityDescription))
                }
            }
        }
        ListDivider()

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Heading(stringResource(R.string.statsExplainTitle))
            BodyText(stringResource(R.string.statsExplainBody))
            Text(stringResource(R.string.statsPrivacyNote), style = Theme.Typography.manrope(12f, FontWeight.Normal), color = Theme.subtleText)
        }
    }
}

/** 10 minutes in a period put a listener on its leaderboard (019). */
private const val RANKED_SECONDS = 600

/**
 * The leaderboard for this week (the default), this month or all time, as `StatsView.swift`
 * (Figma "Statistiky 1.4"). Never shows how many listeners there are; with too few in a
 * period, the listener's own time instead of a place.
 */
@Composable
private fun Leaderboard(ui: StatsUi, onRetry: () -> Unit, onPeriodChanged: (StatsPeriod, ranked: Boolean) -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    val summary = ui.summary
    var periodId by rememberSaveable { mutableStateOf(StatsPeriod.WEEK.id) }
    val period = StatsPeriod.fromId(periodId)
    val standing = summary.period(period)
    StatsPanel(spacing = 18) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                stringResource(if (standing.rank == null && ui.communityUnlocked) R.string.statsPersonalTitle else R.string.statsLeaderboardTitle),
                style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary, modifier = Modifier.weight(1f),
            )
            if (ui.communityUnlocked) {
                Text(
                    stringResource(when (period) { StatsPeriod.WEEK -> R.string.statsPeriodWeekLabel; StatsPeriod.MONTH -> R.string.statsPeriodMonthLabel; StatsPeriod.ALL -> R.string.statsPeriodAllLabel }),
                    style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = Theme.mutedText,
                )
            }
        }
        if (!ui.communityUnlocked) {
            BodyText(stringResource(R.string.statsLeaderboardLocked))
            return@StatsPanel
        }
        PeriodPicker(period) {
            if (it.id != periodId) onPeriodChanged(it, summary.period(it).rank != null)
            periodId = it.id
        }
        val rank = standing.rank
        when {
            rank != null -> {
                Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("#$rank", style = Theme.Typography.manrope(48f, FontWeight.ExtraBold), color = Theme.liveRed, maxLines = 1)
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        StatsTier.label(rank, standing.ranked)?.let { tier ->
                            Text(
                                stringResource(R.string.statsTierTop, tier), style = Theme.Typography.manrope(11f, FontWeight.Bold).copy(letterSpacing = 1.sp), color = GlowLabel,
                                modifier = Modifier.background(Theme.liveRed.copy(alpha = 0.18f), CircleShape).border(1.dp, Theme.liveRed.copy(alpha = 0.5f), CircleShape).padding(horizontal = 10.dp, vertical = 4.dp),
                            )
                        }
                        if (rank == 1 || StatsTier.isLoyal(rank, standing.ranked)) {
                            Text(
                                stringResource(
                                    when {
                                        rank == 1 -> R.string.statsFirstPlace
                                        period == StatsPeriod.WEEK -> R.string.statsTierLoyalWeek
                                        period == StatsPeriod.MONTH -> R.string.statsTierLoyalMonth
                                        else -> R.string.statsTierLoyal
                                    }
                                ),
                                style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText,
                            )
                        }
                    }
                }
                if (standing.aheadSeconds != null || standing.behindSeconds != null) {
                    Column(
                        Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(14.dp)).padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Text(
                            stringResource(when (period) { StatsPeriod.WEEK -> R.string.statsNeighboursWeek; StatsPeriod.MONTH -> R.string.statsNeighboursMonth; StatsPeriod.ALL -> R.string.statsNeighbours }),
                            style = Theme.Typography.manrope(12f, FontWeight.Bold), color = Theme.mutedText,
                        )
                        NeighboursTrack(standing.seconds, rank, standing.aheadSeconds, standing.behindSeconds)
                    }
                }
                PeriodFooter(period)
            }
            summary.totalSeconds == 0 -> BodyText(stringResource(R.string.statsRankNoListening))
            ui.loadFailed && standing.seconds == 0 -> {
                BodyText(stringResource(R.string.statsRankFailed))
                SecondaryActionButton(stringResource(R.string.statsRetry), onClick = onRetry)
            }
            period != StatsPeriod.ALL && standing.isOpen && standing.seconds < RANKED_SECONDS -> {
                ProgressToRank(standing, period)
                PeriodFooter(period)
            }
            else -> {
                Personal(standing, period, english)
                PeriodFooter(period)
            }
        }
        if (ui.loadFailed && summary.totalSeconds > 0) BodyText(stringResource(R.string.statsOfflineNote), color = Theme.subtleText)
    }
}

@Composable
private fun PeriodPicker(selected: StatsPeriod, onSelect: (StatsPeriod) -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(12.dp)).padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        StatsPeriod.entries.forEach { period ->
            val isSelected = period == selected
            Box(
                Modifier
                    .weight(1f)
                    .background(if (isSelected) Color(0xFF3A2F5C) else Color.Transparent, RoundedCornerShape(9.dp))
                    .clickable { onSelect(period) }
                    .semantics { this.selected = isSelected }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(when (period) { StatsPeriod.WEEK -> R.string.statsPeriodWeek; StatsPeriod.MONTH -> R.string.statsPeriodMonth; StatsPeriod.ALL -> R.string.statsPeriodAll }),
                    style = Theme.Typography.manrope(13f, if (isSelected) FontWeight.ExtraBold else FontWeight.SemiBold),
                    color = if (isSelected) Theme.textPrimary else Theme.mutedText,
                )
            }
        }
    }
}

@Composable
private fun PeriodFooter(period: StatsPeriod) {
    Text(
        stringResource(when (period) { StatsPeriod.WEEK -> R.string.statsPeriodFooterWeek; StatsPeriod.MONTH -> R.string.statsPeriodFooterMonth; StatsPeriod.ALL -> R.string.statsPeriodFooterAll }),
        style = Theme.Typography.manrope(14f, FontWeight.Bold).copy(lineHeight = 20.sp), color = Theme.textPrimary,
    )
    Text(stringResource(R.string.statsLeaderboardAnonymous), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText.copy(alpha = 0.75f))
}

/** Figma R4: not on this period's leaderboard yet, and how little is missing. */
@Composable
private fun ProgressToRank(standing: PeriodStanding, period: StatsPeriod) {
    val minutes = minOf(standing.seconds / 60, 9)
    Column(
        Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(14.dp)).padding(14.dp).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            stringResource(if (period == StatsPeriod.WEEK) R.string.statsToRankWeek else R.string.statsToRankMonth, 10 - minutes),
            style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.textPrimary,
        )
        Box(Modifier.fillMaxWidth().height(6.dp).background(Color.White.copy(alpha = 0.1f), CircleShape)) {
            Box(Modifier.fillMaxWidth(standing.seconds.toFloat() / RANKED_SECONDS).height(6.dp).background(Theme.liveRed, CircleShape))
        }
        Text(stringResource(R.string.statsToRankProgress, minutes), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText)
    }
}

/** Figma R7: the listener's own time, compared with the period before — never with others. */
@Composable
private fun Personal(standing: PeriodStanding, period: StatsPeriod, english: Boolean) {
    Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        DurationText(standing.seconds, numberSize = 40f, unitSize = 18f)
        Text(
            stringResource(when (period) { StatsPeriod.WEEK -> R.string.statsPersonalWeek; StatsPeriod.MONTH -> R.string.statsPersonalMonth; StatsPeriod.ALL -> R.string.statsPersonalAll }),
            style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText,
        )
        val previous = standing.previousSeconds
        if (period != StatsPeriod.ALL && previous != null && previous > 0) {
            val difference = standing.seconds - previous
            val amount = StatsFormat.duration(english, kotlin.math.abs(difference))
            val week = period == StatsPeriod.WEEK
            val text = when {
                kotlin.math.abs(difference) < 60 -> stringResource(if (week) R.string.statsSameAsLastWeek else R.string.statsSameAsLastMonth)
                difference > 0 -> stringResource(if (week) R.string.statsMoreThanLastWeek else R.string.statsMoreThanLastMonth, amount)
                else -> stringResource(if (week) R.string.statsLessThanLastWeek else R.string.statsLessThanLastMonth, amount)
            }
            Text(
                text, style = Theme.Typography.manrope(12f, FontWeight.Bold), color = GlowLabel,
                modifier = Modifier.padding(top = 2.dp).background(Theme.liveRed.copy(alpha = 0.18f), CircleShape).padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
    }
}

/** Figma R5: on Monday and Tuesday, how last week went; the place only in the top ten of a week that had places. */
@Composable
private fun LastWeekCard(summary: StatsSummary) {
    val english = LocalAppLanguage.current.isEnglish
    val weekday = java.time.ZonedDateTime.now(java.time.ZoneId.of("Europe/Prague")).dayOfWeek
    if (weekday != java.time.DayOfWeek.MONDAY && weekday != java.time.DayOfWeek.TUESDAY) return
    if (summary.lastWeekSeconds < RANKED_SECONDS) return
    val place = summary.lastWeekRank?.takeIf { it <= 10 }
    val withRadio = stringResource(R.string.statsWithRadio, StatsFormat.duration(english, summary.lastWeekSeconds))
    Column(
        Modifier
            .fillMaxWidth()
            .background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFF3B1F7A), Color(0xFF7A1838))), RoundedCornerShape(20.dp))
            .padding(20.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(stringResource(R.string.statsLastWeekTitle), style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = GlowLabel)
        Text(if (place != null) stringResource(R.string.statsLastWeekPlace, place) else withRadio, style = Theme.Typography.manrope(22f, FontWeight.ExtraBold), color = Theme.textPrimary)
        if (place != null) Text(withRadio, style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = GlowLabel)
        Text(
            stringResource(if (place != null) R.string.statsLastWeekGreat else R.string.statsLastWeekNew),
            style = Theme.Typography.manrope(14f, FontWeight.SemiBold).copy(lineHeight = 20.sp), color = Theme.textPrimary,
            modifier = Modifier.padding(top = 2.dp),
        )
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
        // This week's place only (Statistiky 1.4), never "of N"; no place this week, no row.
        val weekRank = summary.period(StatsPeriod.WEEK).rank
        if (ui.communityUnlocked && weekRank != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.statsLeaderboardWeekScope), style = Theme.Typography.Copy.body, color = Theme.mutedText, maxLines = 1, modifier = Modifier.weight(1f))
                Box(Modifier.background(Theme.liveRed.copy(alpha = 0.08f), RoundedCornerShape(6.dp)).padding(horizontal = 8.dp, vertical = 4.dp)) {
                    Text("#$weekRank", style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = Theme.liveRed)
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
