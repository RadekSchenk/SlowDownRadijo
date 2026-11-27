package cz.slowdownradijo.app.profile

import androidx.compose.animation.togetherWith

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MailOutline
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.account.AccountService.NicknameCheck
import cz.slowdownradijo.app.account.AccountService.SignInMethod
import cz.slowdownradijo.app.account.AccountService.State
import cz.slowdownradijo.app.ui.components.BackHeader
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import cz.slowdownradijo.app.ui.theme.contentColumn

/** What the Profil page can do; the stateful wrapper is `ProfilePage` in MainActivity.kt. */
data class ProfileActions(
    val onApple: () -> Unit = {},
    val onGoogle: () -> Unit = {},
    val onEmail: () -> Unit = {},
    val onNickname: () -> Unit = {},
    val onHiddenUsers: () -> Unit = {},
    val onRules: () -> Unit = {},
    val onPrivacy: () -> Unit = {},
    val onSignOut: () -> Unit = {},
    val onDeleteAccount: () -> Unit = {},
    /** Opens "Přezdívku změníš s účtem" / the sign-up; the reason goes to analytics. */
    val onRegister: (reason: String) -> Unit = {},
    val onAdminModerators: () -> Unit = {},
    val onAdminAdmins: () -> Unit = {},
    val onAdminContests: () -> Unit = {},
    /** "Běží" next to Soutěže. */
    val contestRunning: Boolean = false,
    /** Switches to the Statistiky tab (the row under the Slowrider card). */
    val onOpenStats: () -> Unit = {},
    val checkNickname: suspend (String) -> NicknameCheck? = { null },
    /** Saves the nickname; returns the error to show, or null on success. */
    val saveNickname: suspend (String) -> AccountError? = { null },
)

/**
 * The Profil tab's main page (`ProfileView.swift`, v3): signed out (M2, "Staň se
 * Slowriderem"), writing without an account (M7), the nickname right after the first
 * sign-in (R1), or the Slowrider (M1/M11 with "Tvůj Slowride", M3 moderator, M4 muted,
 * M10 superadmin).
 */
@Composable
fun ProfileContent(
    state: State,
    busy: Boolean,
    actions: ProfileActions,
    now: Instant = Instant.now(),
    stats: SlowrideStats = SlowrideStats(),
) {
    val key = when (state) {
        State.Loading -> "loading"
        State.SignedOut -> "out"
        is State.Anonymous -> "anon"
        is State.SignedIn -> "in"
    }
    androidx.compose.animation.AnimatedContent(
        targetState = key,
        transitionSpec = {
            (androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(300)) +
                androidx.compose.animation.slideInVertically(androidx.compose.animation.core.tween(300)) { it / 20 }) togetherWith
                androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(150))
        },
        label = "profile",
    ) { current ->
        if (current != key) return@AnimatedContent
        when (state) {
            State.Loading -> Box(Modifier.fillMaxWidth().padding(top = 48.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
            }
            State.SignedOut -> SignedOut(busy, actions)
            is State.Anonymous -> Anonymous(state.me, actions, now)
            is State.SignedIn -> {
                val me = state.me
                if (me != null && me.nickname == null && !me.isHost) NicknameSetup(actions)
                else SignedIn(state, actions, now, stats)
            }
        }
    }
}

@Composable
private fun SignedOut(busy: Boolean, actions: ProfileActions) {
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.xl)) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
            Text(stringResource(R.string.profileTitle), style = Theme.Typography.Heading.page, color = Theme.textPrimary)
            ProfileHeading(stringResource(R.string.slowriderTitle), stringResource(R.string.slowriderBenefitsIntro), hero = true)
            SlowriderBenefits()
            SignInButtons(busy, actions.onApple, actions.onGoogle, actions.onEmail)
        }
        ProfileSection(stringResource(R.string.profileOtherSection)) {
            ProfileRow(stringResource(R.string.chatRulesTitle), onClick = actions.onRules)
            ListDivider()
            ProfileRow(stringResource(R.string.settingsPrivacyPolicy), onClick = actions.onPrivacy)
        }
    }
}

@Composable
private fun Identity(name: String, subtitle: String, isHost: Boolean = false, isSuperadmin: Boolean = false) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(name, style = Theme.Typography.Heading.hero, color = Theme.textPrimary, maxLines = 1)
            if (isHost) DjTag()
            if (isSuperadmin) Tag(stringResource(R.string.adminSuperadmin))
        }
        Text(subtitle, style = Theme.Typography.Copy.body, color = Theme.mutedText)
    }
}

@Composable
private fun Tag(text: String) {
    Text(
        text, style = Theme.Typography.manrope(12f, FontWeight.ExtraBold), color = Theme.liveRed,
        modifier = Modifier.background(Theme.liveRed.copy(alpha = 0.16f), RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 1.dp),
    )
}

@Composable
private fun Anonymous(me: AccountService.Me, actions: ProfileActions, now: Instant) {
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.xl)) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
            Text(stringResource(R.string.profileTitle), style = Theme.Typography.Heading.page, color = Theme.textPrimary)
            Identity(me.nickname.orEmpty(), stringResource(R.string.profileWritingWithoutAccount))
            if (me.blocked || (me.mutedUntil?.isAfter(now) == true)) MutedBanner(me.mutedUntil, me.blocked, now)
            SlowriderCard(me.nickname.orEmpty()) { actions.onRegister("profile_card") }
        }
        ProfileSection(stringResource(R.string.profileChatSection)) {
            ProfileRow(stringResource(R.string.profileNickname), me.nickname.orEmpty() + "  🔒", onClick = { actions.onRegister("nickname_change") })
            ListDivider()
            ProfileRow(stringResource(R.string.profileHiddenUsers), onClick = actions.onHiddenUsers)
            ListDivider()
            ProfileRow(stringResource(R.string.chatRulesTitle), onClick = actions.onRules)
        }
        ProfileSection(stringResource(R.string.profileOtherSection)) {
            ProfileRow(stringResource(R.string.settingsPrivacyPolicy), onClick = actions.onPrivacy)
            ListDivider()
            ProfileRow(stringResource(R.string.profileDeleteData), chevron = false, destructive = true, onClick = actions.onDeleteAccount)
        }
    }
}

@Composable
private fun SignedIn(state: State.SignedIn, actions: ProfileActions, now: Instant, stats: SlowrideStats) {
    val me = state.me
    val isHost = me?.isHost == true
    val method = methodName(state.method)
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.xl)) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
            Text(stringResource(R.string.profileTitle), style = Theme.Typography.Heading.page, color = Theme.textPrimary)
            // The Slowrider card carries the name; this only while the profile loads.
            if (me == null) Identity(state.email.orEmpty(), stringResource(R.string.signedInWith, method))
            if (me != null && (me.blocked || (me.mutedUntil?.isAfter(now) == true))) MutedBanner(me.mutedUntil, me.blocked, now)
        }
        if (me != null) SlowrideDashboard(me, stats, now, actions.onOpenStats, actions.onNickname)
        // Figma "Soutěže" P1/P2: contests for admins and the superadmin, moderators
        // and admins for the superadmin only.
        if (me?.isSuperadmin == true || me?.isAdmin == true) {
            ProfileSection(stringResource(R.string.adminSection)) {
                ProfileRow(
                    stringResource(R.string.adminContests),
                    if (actions.contestRunning) stringResource(R.string.adminContestsRunning) else null,
                    valueColor = Theme.sunYellow,
                    onClick = actions.onAdminContests,
                )
                if (me.isSuperadmin) {
                    ListDivider()
                    ProfileRow(stringResource(R.string.adminModerators), onClick = actions.onAdminModerators)
                    ListDivider()
                    ProfileRow(stringResource(R.string.adminAdmins), onClick = actions.onAdminAdmins)
                }
            }
        }
        ProfileSection(stringResource(R.string.profileChatSection)) {
            if (isHost) {
                ProfileRow(stringResource(R.string.profileHostName), stringResource(R.string.profileHostNameValue), chevron = false)
            } else {
                ProfileRow(stringResource(R.string.profileNickname), me?.nickname, onClick = actions.onNickname)
            }
            ListDivider()
            ProfileRow(stringResource(R.string.profileHiddenUsers), onClick = actions.onHiddenUsers)
            ListDivider()
            ProfileRow(stringResource(R.string.chatRulesTitle), onClick = actions.onRules)
        }
        ProfileSection(stringResource(R.string.profileAccountSection)) {
            ProfileRow(stringResource(R.string.profileSignInMethod), method, chevron = false)
            ListDivider()
            ProfileRow(stringResource(R.string.profileSignOut), chevron = false, onClick = actions.onSignOut)
            ListDivider()
            ProfileRow(stringResource(R.string.profileDeleteAccount), chevron = false, destructive = true, onClick = actions.onDeleteAccount)
        }
    }
}

@Composable
private fun methodName(method: SignInMethod?): String = when (method) {
    SignInMethod.APPLE -> "Apple"
    SignInMethod.GOOGLE -> "Google"
    else -> stringResource(R.string.signInMethodEmail)
}

@Composable
fun DjTag() {
    Text(
        stringResource(R.string.chatHostBadge),
        style = Theme.Typography.manrope(12f, FontWeight.ExtraBold), color = Theme.liveRed,
        modifier = Modifier.background(Theme.liveRed.copy(alpha = 0.16f), RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 1.dp),
    )
}

// Building blocks

@Composable
fun ProfileHeading(title: String, body: String? = null, hero: Boolean = false) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = if (hero) Theme.Typography.Heading.hero else Theme.Typography.Heading.page, color = Theme.textPrimary)
        if (body != null) Text(body, style = Theme.Typography.Copy.body, color = Theme.mutedText)
    }
}

@Composable
fun ProfileSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = Theme.Typography.Heading.section, color = Theme.textPrimary)
        Column { content() }
    }
}

@Composable
fun ProfileRow(title: String, value: String? = null, chevron: Boolean = true, destructive: Boolean = false, valueColor: Color = Theme.mutedText, onClick: (() -> Unit)? = null) {
    Row(
        Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier)
            .padding(vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.sm),
    ) {
        Text(title, style = Theme.Typography.Heading.item, color = if (destructive) Theme.liveRed else Theme.textPrimary, modifier = Modifier.weight(1f))
        if (value != null) Text(value, style = Theme.Typography.Copy.body, color = valueColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (chevron) Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.subtleText, modifier = Modifier.size(22.dp))
    }
}

/** "Pokračovat s Apple / s Google / e‑mailem" (`SignInButtons.swift`). */
@Composable
fun SignInButtons(busy: Boolean, onApple: () -> Unit, onGoogle: () -> Unit, onEmail: () -> Unit) {
    Box(contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Apple's web sign-in button: white with the black logo.
            SignInButton(stringResource(R.string.signInApple), Color.White, Color.Black, null, !busy, onApple) {
                Icon(painterResource(R.drawable.apple_logo), contentDescription = null, tint = Color.Black, modifier = Modifier.size(18.dp))
            }
            // Google's dark button: the logo unchanged.
            SignInButton(stringResource(R.string.signInGoogle), Color(0xFF131314), Color(0xFFE3E3E3), BorderStroke(1.dp, Color(0xFF8E918F)), !busy, onGoogle) {
                Image(painterResource(R.drawable.google_logo), contentDescription = null, modifier = Modifier.size(18.dp))
            }
            SignInButton(stringResource(R.string.signInEmail), Theme.hairline(0.08f), Theme.textPrimary, null, !busy, onEmail) {
                Icon(Icons.Rounded.MailOutline, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
            }
        }
        if (busy) CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
    }
}

@Composable
private fun SignInButton(title: String, background: Color, content: Color, border: BorderStroke?, enabled: Boolean, onClick: () -> Unit, icon: @Composable () -> Unit) {
    val shape = RoundedCornerShape(10.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(background.copy(alpha = if (enabled) background.alpha else background.alpha * 0.5f))
            .then(if (border != null) Modifier.border(border, shape) else Modifier)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon()
        Spacer(Modifier.width(10.dp))
        Text(title, style = Theme.Typography.Copy.button, color = content)
    }
}

/** ("dnes" / "zítra" / "20. 11.", "8:04") — `ProfileFormat.dayAndTime`. */
@Composable
fun dayAndTime(at: Instant, now: Instant): Pair<String, String> =
    dayAndTime(at, now, androidx.compose.ui.platform.LocalContext.current)

/** "dnes" / "zítra" / "19. 11." and "8:04", outside composition (toasts). */
fun dayAndTime(at: Instant, now: Instant, context: android.content.Context): Pair<String, String> {
    val zone = ZoneId.systemDefault()
    val local = at.atZone(zone)
    val days = ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(), local.toLocalDate())
    val time = "%d:%02d".format(local.hour, local.minute)
    val day = when (days) {
        0L -> context.getString(R.string.dayToday)
        1L -> context.getString(R.string.dayTomorrow)
        else -> "${local.dayOfMonth}. ${local.monthValue}."
    }
    return day to time
}

/** "Psaní do chatu máš pozastavené do zítra 8:04" (Figma Profil M4). */
@Composable
fun MutedBanner(mutedUntil: Instant?, blocked: Boolean, now: Instant) {
    Row(
        Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(16.dp)).padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.AutoMirrored.Rounded.VolumeOff, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(20.dp))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            val title = if (blocked || mutedUntil == null) stringResource(R.string.blockedBanner) else {
                val (day, time) = dayAndTime(mutedUntil, now)
                stringResource(R.string.mutedBanner, day, time)
            }
            Text(title, style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.textPrimary)
            Text(stringResource(R.string.mutedBannerBody), style = Theme.Typography.Copy.label, color = Theme.mutedText)
        }
    }
}

// Nickname (R1, N1–N3)

enum class NicknameStatus { EMPTY, CHECKING, OK, INVALID, TAKEN, RESERVED, UNCHANGED }

private val nicknamePattern = Regex("^[A-Za-z0-9._]{3,20}$")

/** The nickname field with its live check (`NicknameField` on iOS). */
@Composable
fun NicknameField(
    text: String,
    onText: (String) -> Unit,
    status: NicknameStatus,
    onStatus: (NicknameStatus) -> Unit,
    check: suspend (String) -> NicknameCheck?,
    locked: Boolean = false,
    current: String? = null,
) {
    var focused by remember { mutableStateOf(false) }
    LaunchedEffect(text, locked) {
        if (locked) return@LaunchedEffect
        val nick = text.trim()
        when {
            nick.isEmpty() -> onStatus(NicknameStatus.EMPTY)
            nick == current -> onStatus(NicknameStatus.UNCHANGED)
            !nicknamePattern.matches(nick) -> onStatus(NicknameStatus.INVALID)
            else -> {
                onStatus(NicknameStatus.CHECKING)
                delay(400)
                onStatus(
                    when (check(nick)) {
                        NicknameCheck.TAKEN -> NicknameStatus.TAKEN
                        NicknameCheck.RESERVED -> NicknameStatus.RESERVED
                        NicknameCheck.INVALID -> NicknameStatus.INVALID
                        // OK, or offline: the server decides on save.
                        else -> NicknameStatus.OK
                    }
                )
            }
        }
    }
    val bad = status in setOf(NicknameStatus.INVALID, NicknameStatus.TAKEN, NicknameStatus.RESERVED)
    val border = when {
        locked -> Color.Transparent
        status == NicknameStatus.OK -> Theme.spotifyGreen
        bad -> Theme.liveRed
        focused -> Theme.mutedText.copy(alpha = 0.6f)
        else -> Color.Transparent
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row {
            Text(stringResource(R.string.profileNickname), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.mutedText, modifier = Modifier.weight(1f))
            if (!locked) Text("${text.length}/20", style = Theme.Typography.Copy.label, color = Theme.subtleText)
        }
        Row(
            Modifier
                .fillMaxWidth()
                .height(50.dp)
                .background(if (locked) Theme.statsCard else Theme.statsCardRaised, RoundedCornerShape(10.dp))
                .border(1.5.dp, border, RoundedCornerShape(10.dp))
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.weight(1f)) {
                if (text.isEmpty()) Text(stringResource(R.string.nicknamePlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                BasicTextField(
                    value = text,
                    onValueChange = { onText(it.take(20)) },
                    enabled = !locked,
                    singleLine = true,
                    textStyle = Theme.Typography.Copy.reading.copy(color = if (locked) Theme.subtleText else Theme.textPrimary),
                    cursorBrush = SolidColor(Theme.textPrimary),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, keyboardType = KeyboardType.Ascii),
                    modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                )
            }
            when {
                locked -> Icon(Icons.Rounded.Lock, contentDescription = null, tint = Theme.subtleText, modifier = Modifier.size(18.dp))
                status == NicknameStatus.CHECKING -> CircularProgressIndicator(color = Theme.mutedText, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                status == NicknameStatus.OK -> Icon(Icons.Rounded.Check, contentDescription = null, tint = Theme.spotifyGreen, modifier = Modifier.size(20.dp))
                bad -> Icon(Icons.Rounded.ErrorOutline, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.size(20.dp))
            }
        }
        val message = when (status) {
            NicknameStatus.OK -> R.string.nicknameAvailable
            NicknameStatus.TAKEN -> R.string.nicknameTaken
            NicknameStatus.RESERVED -> R.string.nicknameReserved
            NicknameStatus.INVALID -> R.string.nicknameInvalid
            else -> null
        }
        if (message != null && !locked) {
            Text(stringResource(message), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = if (status == NicknameStatus.OK) Theme.spotifyGreen else Theme.liveRed)
        }
    }
}

fun AccountError.asNicknameStatus(): NicknameStatus? = when (this) {
    AccountError.NicknameTaken -> NicknameStatus.TAKEN
    AccountError.NicknameReserved -> NicknameStatus.RESERVED
    AccountError.NicknameInvalid -> NicknameStatus.INVALID
    else -> null
}

/** "Ještě přezdívka" (Figma Profil R1). */
@Composable
fun NicknameSetup(actions: ProfileActions, initial: String = "", initialStatus: NicknameStatus = NicknameStatus.EMPTY) {
    var nickname by rememberSaveable { mutableStateOf(initial) }
    var status by remember { mutableStateOf(initialStatus) }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
        ProfileHeading(stringResource(R.string.nicknameSetupTitle), stringResource(R.string.nicknameSetupBody))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            NicknameField(nickname, { nickname = it }, status, { status = it }, actions.checkNickname)
            Text(stringResource(R.string.nicknameRules), style = Theme.Typography.Copy.label, color = Theme.subtleText)
        }
        PrimaryActionButton(stringResource(R.string.nicknameDone), enabled = status == NicknameStatus.OK && !saving) {
            saving = true
            scope.launch {
                actions.saveNickname(nickname.trim())?.let { error -> error.asNicknameStatus()?.let { status = it } }
                saving = false
            }
        }
    }
}

/** Changing the nickname (Figma N1–N3): once per 24 h, confirmed, locked while waiting. */
@Composable
fun NicknameEditScreen(me: AccountService.Me?, actions: ProfileActions, back: () -> Unit, now: Instant = Instant.now()) {
    var nickname by rememberSaveable { mutableStateOf(me?.nickname.orEmpty()) }
    var status by remember { mutableStateOf(NicknameStatus.UNCHANGED) }
    var confirming by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val nextChange = me?.nicknameNextChangeAt?.takeIf { it.isAfter(now) }
    SubPage(stringResource(R.string.profileNickname), back) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            NicknameField(nickname, { nickname = it }, status, { status = it }, actions.checkNickname, locked = nextChange != null, current = me?.nickname)
            if (nextChange != null) {
                val (day, time) = dayAndTime(nextChange, now)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Rounded.Schedule, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(18.dp))
                    Text(stringResource(R.string.nicknameCooldown, day, time), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                }
            } else {
                Text(stringResource(R.string.nicknameRules), style = Theme.Typography.Copy.label, color = Theme.subtleText)
            }
        }
        PrimaryActionButton(stringResource(R.string.nicknameSave), enabled = nextChange == null && status == NicknameStatus.OK && !saving) { confirming = true }
    }
    if (confirming) {
        ConfirmDialog(
            title = stringResource(R.string.nicknameConfirmTitle, nickname.trim()),
            body = stringResource(R.string.nicknameConfirmBody),
            confirm = stringResource(R.string.nicknameConfirmAction),
            destructive = false,
            onDismiss = { confirming = false },
        ) {
            confirming = false
            saving = true
            scope.launch {
                val error = actions.saveNickname(nickname.trim())
                saving = false
                if (error == null) back() else error.asNicknameStatus()?.let { status = it }
            }
        }
    }
}

// E-mail code (E1–E3)

/** Signing in with an e‑mail code (`EmailSignInView.swift`). */
@Composable
fun EmailSignInScreen(
    sendCode: suspend (String) -> AccountService.EmailCodeRequest,
    verify: suspend (String, AccountService.EmailCodeRequest) -> Unit,
    back: () -> Unit,
    onSignedIn: () -> Unit,
    initialEmail: String = "",
    initialRequest: AccountService.EmailCodeRequest? = null,
    initialCode: String = "",
    initialCodeInvalid: Boolean = false,
) {
    var email by rememberSaveable { mutableStateOf(initialEmail) }
    var request by remember { mutableStateOf(initialRequest) }
    var code by remember { mutableStateOf(initialCode) }
    var codeInvalid by remember { mutableStateOf(initialCodeInvalid) }
    var emailError by remember { mutableStateOf<Int?>(null) }
    var working by remember { mutableStateOf(false) }
    var resendAt by remember { mutableStateOf(System.currentTimeMillis() + 60_000) }
    val scope = rememberCoroutineScope()
    val codeFocus = remember { FocusRequester() }

    fun send() {
        val address = email.trim()
        if (!Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").matches(address)) {
            emailError = R.string.emailInvalidAddress
            return
        }
        emailError = null
        working = true
        scope.launch {
            try {
                request = sendCode(address)
                resendAt = System.currentTimeMillis() + 60_000
            } catch (e: AccountError) {
                emailError = e.messageRes
            } finally {
                working = false
            }
        }
    }

    fun check(current: AccountService.EmailCodeRequest) {
        if (working) return
        working = true
        scope.launch {
            try {
                verify(code, current)
                onSignedIn()
            } catch (e: AccountError) {
                if (e == AccountError.CodeInvalid) codeInvalid = true
            } finally {
                working = false
            }
        }
    }

    val current = request
    SubPage(
        stringResource(if (current == null) R.string.emailSignInTitle else R.string.emailCodeTitle),
        back = { if (current != null) { request = null; code = ""; codeInvalid = false } else back() },
    ) {
        if (current == null) {
            Text(stringResource(R.string.emailSignInBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.emailFieldLabel), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.mutedText)
                Box(
                    Modifier.fillMaxWidth().height(50.dp).background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 16.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (email.isEmpty()) Text(stringResource(R.string.emailFieldPlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                    BasicTextField(
                        value = email,
                        onValueChange = { email = it },
                        singleLine = true,
                        textStyle = Theme.Typography.Copy.reading.copy(color = Theme.textPrimary),
                        cursorBrush = SolidColor(Theme.textPrimary),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrectEnabled = false, imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { send() }),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                emailError?.let { Text(stringResource(it), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.liveRed) }
            }
            PrimaryActionButton(stringResource(R.string.emailSendCode), enabled = !working && email.isNotBlank()) { send() }
            Text(stringResource(R.string.emailNewAccountNote), style = Theme.Typography.Copy.label, color = Theme.subtleText)
        } else {
            Text(stringResource(R.string.emailCodeBody, current.email), style = Theme.Typography.Copy.body, color = Theme.mutedText)
            BasicTextField(
                value = code,
                onValueChange = { new ->
                    code = new.filter(Char::isDigit).take(6)
                    codeInvalid = false
                    if (code.length == 6) check(current)
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.focusRequester(codeFocus),
                decorationBox = {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        repeat(6) { index ->
                            val digit = code.getOrNull(index)?.toString().orEmpty()
                            val currentBox = index == code.length
                            Box(
                                Modifier
                                    .weight(1f)
                                    .height(58.dp)
                                    .background(Theme.statsCardRaised, RoundedCornerShape(10.dp))
                                    .border(
                                        1.5.dp,
                                        if (codeInvalid) Theme.liveRed else if (currentBox) Theme.mutedText.copy(alpha = 0.8f) else Color.Transparent,
                                        RoundedCornerShape(10.dp),
                                    ),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(digit, style = Theme.Typography.manrope(24f, FontWeight.ExtraBold), color = Theme.textPrimary, textAlign = TextAlign.Center)
                            }
                        }
                    }
                },
            )
            LaunchedEffect(Unit) { runCatching { codeFocus.requestFocus() } }
            if (codeInvalid) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.ErrorOutline, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.size(16.dp))
                    Text(stringResource(R.string.emailCodeInvalid), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.liveRed)
                }
            }
            var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
            LaunchedEffect(resendAt) {
                while (nowMillis < resendAt) {
                    delay(1000)
                    nowMillis = System.currentTimeMillis()
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
                val left = ((resendAt - nowMillis + 999) / 1000).toInt()
                if (left > 0) {
                    Text(stringResource(R.string.emailResendIn, "%d:%02d".format(left / 60, left % 60)), style = Theme.Typography.Copy.body, color = Theme.subtleText)
                } else {
                    Text(stringResource(R.string.emailResend), style = Theme.Typography.Copy.link, color = Theme.mutedText, modifier = Modifier.clickable { send() })
                }
                Text(
                    stringResource(R.string.emailChange), style = Theme.Typography.Copy.link, color = Theme.mutedText,
                    modifier = Modifier.clickable { request = null; code = ""; codeInvalid = false },
                )
            }
            if (working) CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
        }
    }
}

// Hidden listeners (S1), chat rules (S2)

@Composable
fun HiddenUsersScreen(users: List<AccountService.HiddenUser>?, onShow: (AccountService.HiddenUser) -> Unit, back: () -> Unit) {
    SubPage(stringResource(R.string.profileHiddenUsers), back) {
        Text(stringResource(R.string.hiddenUsersBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        if (users != null && users.isEmpty()) {
            Text(stringResource(R.string.hiddenUsersEmpty), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
        } else if (users != null) {
            Column {
                for (user in users) {
                    ListDivider()
                    Row(Modifier.fillMaxWidth().padding(vertical = 18.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(user.name ?: stringResource(R.string.deletedAccount), style = Theme.Typography.Heading.item, color = Theme.textPrimary, modifier = Modifier.weight(1f))
                        Text(stringResource(R.string.hiddenUsersShow), style = Theme.Typography.Copy.link, color = Theme.liveRed, modifier = Modifier.clickable(role = Role.Button) { onShow(user) })
                    }
                }
                ListDivider()
            }
        }
    }
}

@Composable
fun ChatRulesScreen(back: () -> Unit) {
    SubPage(stringResource(R.string.chatRulesTitle), back) {
        Text(stringResource(R.string.chatRulesIntro), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            listOf(R.string.chatRule1, R.string.chatRule2, R.string.chatRule3, R.string.chatRule4, R.string.chatRule5).forEachIndexed { index, rule ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("${index + 1}", style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.liveRed)
                    Text(stringResource(rule), style = Theme.Typography.Copy.reading, color = Theme.textPrimary)
                }
            }
        }
    }
}

/** A pushed page inside the Profil tab: back header, then the content. */
@Composable
fun SubPage(title: String, back: () -> Unit, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).contentColumn().statusBarsPadding().padding(horizontal = 20.dp).padding(top = 16.dp, bottom = 36.dp),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(title, stringResource(R.string.close), back)
        content()
    }
}

@Composable
fun ConfirmDialog(title: String, body: String, confirm: String, destructive: Boolean, cancel: String? = null, onDismiss: () -> Unit, onConfirm: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Theme.statsCard,
        title = { Text(title, style = Theme.Typography.Heading.hero, color = Theme.textPrimary) },
        text = { Text(body, style = Theme.Typography.Copy.body, color = Theme.mutedText) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirm, style = Theme.Typography.Copy.link, color = if (destructive) Theme.liveRed else Theme.textPrimary) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(cancel ?: stringResource(R.string.cancel), style = Theme.Typography.Copy.link, color = Theme.mutedText) }
        },
    )
}
