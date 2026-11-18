package cz.slowdownradijo.app.profile

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
data class SlowrideStats(val totalSeconds: Int = 0, val topShows: List<Pair<String, Int>> = emptyList())

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

/** "Tvůj Slowride" (Figma Profil M11). Numbers count in when they change. */
@Composable
fun SlowrideDashboard(me: AccountService.Me, stats: SlowrideStats, now: Instant) {
    val english = LocalAppLanguage.current.isEnglish
    val days = me.registeredAt?.let {
        val zone = ZoneId.of("Europe/Prague")
        (ChronoUnit.DAYS.between(it.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate()) + 1).toInt().coerceAtLeast(1)
    } ?: 0
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.slowrideTitle), style = Theme.Typography.Heading.section, color = Theme.textPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Tile(stringResource(R.string.slowrideMember), "$days", L10nLogic.slowrideDays(english, days), Modifier.weight(1f))
            Box(Modifier.weight(1f)) {
                Column(
                    Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(stringResource(R.string.slowrideListened), style = Theme.Typography.Copy.label, color = Theme.mutedText, maxLines = 1)
                    cz.slowdownradijo.app.stats.DurationText(stats.totalSeconds, 22f, 13f)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Tile(stringResource(R.string.slowrideChatMessages), "${me.chatMessagesCount}", null, Modifier.weight(1f))
            Tile(stringResource(R.string.slowrideVoiceMessages), "${me.voiceMessagesCount}", null, Modifier.weight(1f))
        }
        if (stats.topShows.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.slowrideTopShows), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.mutedText)
                stats.topShows.take(3).forEachIndexed { index, (name, seconds) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("${index + 1}", style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = if (index == 0) Theme.liveRed else Theme.mutedText, modifier = Modifier.width(14.dp))
                        Text(name, style = Theme.Typography.Heading.item, color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                        Text(StatsFormat.compactDuration(english, seconds), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                    }
                    HorizontalDivider(color = Theme.hairline(0.08f))
                }
            }
        }
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
