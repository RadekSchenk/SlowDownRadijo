package cz.slowdownradijo.app.profile

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.stats.GlowCard
import cz.slowdownradijo.app.stats.GlowLabel
import cz.slowdownradijo.app.stats.GlowStyle
import cz.slowdownradijo.app.stats.ShowBarRow
import cz.slowdownradijo.app.stats.StatsPanel
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.stats.StatsFormat
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** What the "Tvůj Slowride" dashboard shows from the listening stats. */
data class SlowrideStats(
    val totalSeconds: Int = 0,
    val topShows: List<Pair<String, Int>> = emptyList(),
    val todaySeconds: Int = 0,
    val weekSeconds: Int = 0,
)

/**
 * The account's benefits on the empty Profil (Figma Profil M2), revealed one after
 * another the first time. As `SlowriderBenefits` in SlowriderViews.swift.
 */
@Composable
fun SlowriderBenefits() {
    val items = listOf(
        R.string.benefitProfileTitle to R.string.benefitProfileBody,
        R.string.benefitStatsTitle to R.string.benefitStatsBody,
        R.string.benefitMoreTitle to R.string.benefitMoreBody,
    )
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    var shown by remember { mutableIntStateOf(if (animate) 0 else items.size) }
    LaunchedEffect(Unit) {
        for (i in shown + 1..items.size) {
            delay(if (i == 1) 150 else 120)
            shown = i
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items.forEachIndexed { index, (title, body) ->
            AnimatedVisibility(
                visible = index < shown,
                enter = fadeIn(tween(350)) + slideInVertically(tween(350)) { it / 4 },
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(22.dp).background(Theme.liveRed.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
                        Text("✓", style = Theme.Typography.manrope(12f, FontWeight.ExtraBold), color = Theme.liveRed)
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(stringResource(title), style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = Theme.textPrimary)
                        Text(stringResource(body), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                    }
                }
            }
        }
    }
}

/** "Staň se Slowriderem" for someone who writes without an account (Figma Profil M7). */
@Composable
fun SlowriderCard(nickname: String, onRegister: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(16.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.slowriderTitle), style = Theme.Typography.Heading.item, color = Theme.textPrimary)
        Text(stringResource(R.string.slowriderCardBody, nickname), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        PrimaryActionButton(stringResource(R.string.slowriderRegister), onClick = onRegister)
    }
}

/**
 * Profil of a Slowrider (Figma M15), as `SlowrideDashboard` in SlowriderViews.swift: the
 * member card, a row into Statistiky with today and this week, and the three most
 * listened shows. The card's darker wine look keeps Profil apart from Statistiky.
 */
@Composable
fun SlowrideDashboard(me: AccountService.Me, stats: SlowrideStats, now: Instant, onOpenStats: () -> Unit = {}) {
    val english = LocalAppLanguage.current.isEnglish
    val zone = ZoneId.of("Europe/Prague")
    val days = me.registeredAt?.let {
        (ChronoUnit.DAYS.between(it.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate()) + 1).toInt().coerceAtLeast(1)
    } ?: 0
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        GlowCard(GlowStyle.MEMBER) {
            Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        if (me.isHost) stringResource(R.string.chatHostBadge).uppercase() else stringResource(R.string.memberKicker),
                        style = Theme.Typography.manrope(11f, FontWeight.Bold).copy(letterSpacing = 2.4.sp), color = GlowLabel,
                    )
                    if (me.isSuperadmin) {
                        Text(
                            stringResource(R.string.adminSuperadmin).uppercase(), style = Theme.Typography.manrope(10f, FontWeight.Bold).copy(letterSpacing = 1.sp), color = GlowLabel,
                            modifier = Modifier.background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(50)).padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
                Text(me.chatName.orEmpty(), style = Theme.Typography.manrope(26f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                me.registeredAt?.atZone(zone)?.let {
                    Text(stringResource(R.string.memberSince, "${it.dayOfMonth}. ${it.monthValue}. ${it.year}"), style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = Theme.mutedText)
                }
            }
            Canvas(Modifier.fillMaxWidth().height(2.dp).padding(vertical = 0.dp)) {
                drawLine(
                    Color.White.copy(alpha = 0.22f), Offset(0f, size.height / 2), Offset(size.width, size.height / 2),
                    strokeWidth = 1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 5.dp.toPx())),
                )
            }
            Column(Modifier.semantics(mergeDescendants = true) {}) {
                Text(stringResource(R.string.memberListened), style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = GlowLabel)
                cz.slowdownradijo.app.stats.DurationText(stats.totalSeconds, 44f, 20f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MemberNumber("${me.chatMessagesCount}", stringResource(R.string.memberChat), Modifier.weight(1f))
                MemberNumber("${me.voiceMessagesCount}", stringResource(R.string.memberVoice), Modifier.weight(1f))
                MemberNumber("$days ${L10nLogic.slowrideDays(english, days)}", stringResource(R.string.memberOnBoard), Modifier.weight(1f))
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Theme.statsCardRaised).clickable(onClick = onOpenStats).padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(
                    stringResource(R.string.profileStatsLinkTitle, StatsFormat.duration(english, stats.todaySeconds), StatsFormat.duration(english, stats.weekSeconds)),
                    style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.textPrimary,
                )
                Text(stringResource(R.string.profileStatsLinkSubtitle), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText)
            }
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Theme.mutedText)
        }
        if (stats.topShows.isNotEmpty()) {
            StatsPanel(spacing = 16) {
                Text(stringResource(R.string.slowrideTopShows), style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary)
                val top = stats.topShows.first().second
                stats.topShows.take(3).forEachIndexed { index, (name, seconds) ->
                    ShowBarRow(name, null, seconds, seconds.toDouble() / maxOf(top, 1), rank = index + 1, leader = index == 0)
                }
            }
        }
    }
}

@Composable
private fun MemberNumber(value: String, label: String, modifier: Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(value, style = Theme.Typography.manrope(22f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1)
        Text(label, style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
    }
}

@Composable
private fun Tile(label: String, number: String, unit: String?, modifier: Modifier) {
    Column(
        modifier.background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, style = Theme.Typography.Copy.label, color = Theme.mutedText, maxLines = 1)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
            AnimatedContent(
                targetState = number,
                transitionSpec = {
                    if (animate) (fadeIn(tween(250)) + scaleIn(tween(250), initialScale = 0.6f)) togetherWith fadeOut(tween(150))
                    else fadeIn(tween(0)) togetherWith fadeOut(tween(0))
                },
                label = "tile",
            ) { value ->
                Text(value, style = Theme.Typography.manrope(22f, FontWeight.ExtraBold), color = Theme.textPrimary)
            }
            if (unit != null) Text(unit, style = Theme.Typography.Copy.label, color = Theme.mutedText, modifier = Modifier.padding(bottom = 3.dp))
        }
    }
}

/** "Přezdívku změníš s účtem" / the card's sign-up (Figma Profil M8). */
@Composable
fun RegisterContent(reason: String, nickname: String, busy: Boolean, actions: ProfileActions, onDismiss: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        ProfileHeading(
            stringResource(if (reason == "nickname_change") R.string.registerNicknameTitle else R.string.slowriderTitle),
            stringResource(R.string.registerBody, nickname), hero = true,
        )
        SignInButtons(busy, actions.onApple, actions.onGoogle, actions.onEmail)
        Text(
            stringResource(R.string.chatNotNow), style = Theme.Typography.Copy.link, color = Theme.mutedText, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().clickable(onClick = onDismiss).padding(vertical = 4.dp),
        )
    }
}
