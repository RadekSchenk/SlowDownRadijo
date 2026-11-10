package cz.slowdownradijo.app.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.player.AudioOutputInfo
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.ui.components.Hamburger
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Duration
import java.time.Instant

/** Everything the home screen draws, so screenshot tests can set it. */
data class HomeUi(
    val onAir: OnAir,
    val playback: PlaybackState,
    val sleepTimerFireAt: Instant?,
    val now: Instant,
    val output: AudioOutputInfo = AudioOutputInfo.phone,
)

class HomeActions(
    val togglePlay: () -> Unit = {},
    val openSleepTimer: () -> Unit = {},
    val openSong: (NowPlayingTrack) -> Unit = {},
    val openMenu: () -> Unit = {},
    val openOutputPicker: () -> Unit = {},
)

/**
 * The home screen, as `HomeView.swift`. Phase 1: the header (Figma
 * "Homepage — kompaktní seznam"): the menu and ON-AIR, the logo, the
 * compact player (cover with equalizer, the show and host, the song) and
 * the player controls, with the clouds drifting behind.
 */
@Composable
fun HomeScreen(ui: HomeUi, actions: HomeActions, below: @Composable ColumnScope.() -> Unit = {}) {
    val isPlaying = ui.playback == PlaybackState.Playing
    Box(
        Modifier
            .fillMaxSize()
            .background(Theme.background)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .headerClouds(isPlaying)
                .padding(horizontal = 20.dp)
                .navigationBarsPadding()
                .padding(bottom = Theme.Spacing.xl),
        ) {
            Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            NowPlayingHeader(ui, actions)
            below()
        }
    }
}

@Composable
private fun NowPlayingHeader(ui: HomeUi, actions: HomeActions) {
    val show = ui.onAir.show
    val isPlaying = ui.playback == PlaybackState.Playing
    Column {
        // The 66-high header bar, the logo hanging 22 below its top between the pills.
        Box(Modifier.fillMaxWidth()) {
            AppHeader(hostedShowOnAir = show?.hostName != null, onMenu = actions.openMenu)
            Image(
                painterResource(R.drawable.brand_logo), contentDescription = null,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 22.dp)
                    .size(80.dp, 67.dp),
            )
        }
        Spacer(Modifier.height(22.dp + 67.dp + 10.dp - 66.dp))

        ShowRow(ui)

        AnimatedVisibility(
            visible = ui.onAir.verifiedTrack != null,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically(),
        ) {
            ui.onAir.verifiedTrack?.let { track ->
                SongLine(track, Modifier.padding(top = 16.dp)) { actions.openSong(track) }
            }
        }

        Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (show != null) ShowProgressBar(show, ui.onAir.progress, isPlaying)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (show != null) {
                        Text(
                            remainingLabel(ui.onAir.showEnd, ui.now),
                            style = Theme.Typography.Copy.body.tabular(),
                            color = Theme.mutedText, maxLines = 1,
                        )
                    }
                    SleepTimerLink(ui.sleepTimerFireAt, ui.now, actions.openSleepTimer)
                }
                // Where it plays, next to whether it plays.
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    OutputPickerButton(ui.output, actions.openOutputPicker)
                    PlayButton(ui.playback, actions.togglePlay)
                }
            }
            StatusLabel(ui.playback)
        }
    }
}

/** MENU on the left, ON-AIR on the right while a hosted show is on (`AppHeaderView.swift`). */
@Composable
fun AppHeader(hostedShowOnAir: Boolean, onMenu: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 66.dp)
            .padding(vertical = Theme.Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MenuButton(onMenu)
        Spacer(Modifier.weight(1f))
        if (hostedShowOnAir) OnAirBadge()
    }
}

@Composable
private fun remainingLabel(end: Instant?, now: Instant): String {
    val english = LocalAppLanguage.current.isEnglish
    val minutes = end?.let { (Duration.between(now, it).toMillis() + 59_999) / 60_000 } ?: 0
    if (minutes <= 0) return stringResource(R.string.showEndingNow)
    return stringResource(R.string.showEndsIn, L10nLogic.remaining(english, (minutes / 60).toInt(), (minutes % 60).toInt()))
}

/** The cover with its equalizer, 14, then the show's own title and host. */
@Composable
private fun ShowRow(ui: HomeUi) {
    val show = ui.onAir.show
    val english = LocalAppLanguage.current.isEnglish
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        NowPlayingCover(show, ui.playback == PlaybackState.Playing)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                show?.displayTitle ?: show?.localizedName(english) ?: NowPlayingModel.STATION,
                style = Theme.Typography.Heading.hero.copy(lineHeight = 25.2.sp),
                color = Theme.textPrimary, maxLines = 3, overflow = TextOverflow.Ellipsis,
            )
            show?.hostName?.let { host ->
                Text(
                    "${stringResource(R.string.hostedByKicker)} $host",
                    style = Theme.Typography.Copy.label, color = Theme.mutedText, maxLines = 2,
                )
            }
        }
    }
}

/** "Artist – Title" and the Spotify mark; opens a Spotify search (`SongHistoryLine`, compact). */
@Composable
private fun SongLine(track: NowPlayingTrack, modifier: Modifier, onClick: () -> Unit) {
    val hint = stringResource(R.string.spotifyFindAction)
    Row(
        modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .semantics { contentDescription = "${track.artist} – ${track.title}. $hint" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            "${track.artist} – ${track.title}",
            style = Theme.Typography.Copy.body.copy(lineHeight = 20.3.sp),
            color = Theme.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Image(painterResource(R.drawable.spotify_icon), contentDescription = null, modifier = Modifier.size(19.dp, 19.6.dp))
    }
}

@Composable
private fun StatusLabel(state: PlaybackState) {
    val style = Theme.Typography.manrope(12f, FontWeight.Normal)
    when (state) {
        PlaybackState.Error -> Text(stringResource(R.string.streamInterrupted), style = style, color = Theme.statusError)
        PlaybackState.Connecting -> Text(stringResource(R.string.connecting), style = style, color = Theme.lavender)
        else -> Unit
    }
}

@Composable
private fun MenuButton(onClick: () -> Unit) {
    val label = stringResource(R.string.hubTitle)
    Row(
        Modifier
            .clickable(onClick = onClick)
            .semantics { contentDescription = label }
            .padding(start = 12.dp, end = 10.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Hamburger(Theme.textPrimary)
        Text(label.uppercase(), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.textPrimary)
    }
}

private val onAirRed = Color(0xFFD91F1F)

/** The red dot breathing next to ON-AIR, shown while a hosted show is on (`OnAirBadge`). */
@Composable
private fun OnAirBadge() {
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    val pulse = if (animate) {
        rememberInfiniteTransition(label = "onair").animateFloat(
            0.35f, 1f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "dot",
        ).value
    } else 1f
    Row(
        Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            Modifier
                .size(10.dp)
                .alpha(pulse)
                .background(onAirRed, CircleShape)
        )
        Text(stringResource(R.string.onAir), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = onAirRed)
    }
}
