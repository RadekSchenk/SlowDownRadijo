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
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import coil3.compose.AsyncImage
import cz.slowdownradijo.app.home.ShowArtworkPlaceholder
import cz.slowdownradijo.app.stats.StatsSummary
import cz.slowdownradijo.app.data.SharedImages
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
import cz.slowdownradijo.app.ui.theme.contentColumn

/** What the "Tvůj Slowride" dashboard shows from the listening stats. */
data class SlowrideStats(
    val totalSeconds: Int = 0,
    /** The favourite shows, most listened first (`StatsSummary.shows`). */
    val topShows: List<StatsSummary.ShowShare> = emptyList(),
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
 * Profil of a Slowrider (Figma "Explorace — Profil v2", P1), as `SlowrideDashboard` in
 * SlowriderViews.swift: laid out like a profile, not like Statistiky — the nickname
 * large, a row of numbers, "Upravit přezdívku" and "Moje statistiky", and the three
 * favourite shows as a grid of photos.
 */
@Composable
fun SlowrideDashboard(me: AccountService.Me, stats: SlowrideStats, now: Instant, onOpenStats: () -> Unit = {}, onEditNickname: () -> Unit = {}) {
    val english = LocalAppLanguage.current.isEnglish
    val zone = ZoneId.of("Europe/Prague")
    val days = me.registeredAt?.let {
        (ChronoUnit.DAYS.between(it.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate()) + 1).toInt().coerceAtLeast(1)
    } ?: 0
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    me.chatName.orEmpty(), style = Theme.Typography.manrope(30f, FontWeight.ExtraBold), color = Theme.textPrimary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                )
                MemberPill(if (me.isHost) stringResource(R.string.chatHostBadge).uppercase() else stringResource(R.string.memberKicker))
                if (me.isSuperadmin) MemberPill(stringResource(R.string.adminSuperadmin).uppercase())
            }
            me.registeredAt?.atZone(zone)?.let {
                Text(stringResource(R.string.slowriderSinceLong, "${it.dayOfMonth}. ${it.monthValue}. ${it.year}"), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText)
            }
        }
        // Like a profile's posts / followers row: numbers in a line, no boxes.
        val hours = stats.totalSeconds / 3600
        Row(Modifier.fillMaxWidth().padding(top = 2.dp)) {
            Counter(if (hours > 0) "${StatsFormat.number(english, hours)} h" else StatsFormat.duration(english, stats.totalSeconds), stringResource(R.string.memberListenedShort), Modifier.weight(1f))
            Counter("${me.chatMessagesCount}", L10nLogic.memberMessages(english, me.chatMessagesCount), Modifier.weight(1f))
            Counter("${me.voiceMessagesCount}", L10nLogic.memberVoiceMessages(english, me.voiceMessagesCount), Modifier.weight(1f))
            Counter("$days", L10nLogic.slowrideDays(english, days), Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!me.isHost) ProfileButton(stringResource(R.string.profileEditNickname), onEditNickname, Modifier.weight(1f))
            ProfileButton(stringResource(R.string.profileMyStats), onOpenStats, Modifier.weight(1f))
        }
        if (stats.topShows.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.profileFavouriteShows), style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (index in 0 until 3) {
                        val share = stats.topShows.getOrNull(index)
                        if (share == null) Box(Modifier.weight(1f)) else ShowTile(share, index + 1, Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun MemberPill(text: String) {
    Text(
        text, style = Theme.Typography.manrope(10f, FontWeight.Bold).copy(letterSpacing = 1.2.sp), color = GlowLabel, maxLines = 1,
        modifier = Modifier.background(Theme.liveRed.copy(alpha = 0.16f), RoundedCornerShape(8.dp)).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

@Composable
private fun Counter(value: String, label: String, modifier: Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = Theme.Typography.manrope(22f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1)
        Text(label, style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.mutedText, maxLines = 1)
    }
}

@Composable
private fun ProfileButton(title: String, onClick: () -> Unit, modifier: Modifier) {
    Box(
        modifier.clip(RoundedCornerShape(10.dp)).background(Theme.statsCardRaised).clickable(onClick = onClick).padding(vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary, maxLines = 1)
    }
}

/** One favourite show as a square photo with its place and time, the name under it. */
@Composable
private fun ShowTile(share: StatsSummary.ShowShare, rank: Int, modifier: Modifier) {
    val english = LocalAppLanguage.current.isEnglish
    Column(modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(12.dp))) {
            val bundled = SharedImages.drawable(share.artworkName)
            val photo = Modifier.matchParentSize()
            when {
                bundled != null -> Image(painterResource(bundled), null, photo, contentScale = ContentScale.Crop)
                share.imageURL != null -> AsyncImage(share.imageURL, null, photo.background(Theme.brandPurple), contentScale = ContentScale.Crop)
                else -> ShowArtworkPlaceholder(photo)
            }
            Box(Modifier.matchParentSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color(0xD9120E25))))
            Text(
                "$rank", style = Theme.Typography.manrope(12f, FontWeight.ExtraBold), color = Theme.textPrimary,
                modifier = Modifier.padding(8.dp).background(if (rank == 1) Theme.liveRed else Color(0xBF120E25), RoundedCornerShape(8.dp)).padding(horizontal = 7.dp, vertical = 2.dp),
            )
            Text(
                StatsFormat.compactDuration(english, share.seconds), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.textPrimary,
                modifier = Modifier.align(Alignment.BottomStart).padding(10.dp),
            )
        }
        Text(share.name ?: stringResource(R.string.statsUnknownShow), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
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
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).contentColumn().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding(),
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
