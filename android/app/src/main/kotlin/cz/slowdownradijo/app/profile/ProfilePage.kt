package cz.slowdownradijo.app.profile

import androidx.compose.foundation.layout.imePadding

import androidx.compose.foundation.layout.fillMaxHeight

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.home.AppHeader
import cz.slowdownradijo.app.ui.components.ToastCenter
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

private enum class ProfileRoute { MAIN, EMAIL, NICKNAME, HIDDEN, RULES, ADMIN, CONTESTS }

private const val PRIVACY_POLICY = "https://slowdownradijo.cz/ochrana-osobnich-udaju/"

/** The Profil tab (`ProfileView.swift`): its page and the pages it pushes. */
@Composable
fun ProfilePage(onOpenMenu: () -> Unit, onOpenStats: () -> Unit = {}) {
    val context = LocalContext.current
    val app = context.app
    val account = app.account
    val state by account.state.collectAsStateWithLifecycle()
    val onAir by app.nowPlaying.onAir.collectAsStateWithLifecycle()
    var route by rememberSaveable { mutableStateOf(ProfileRoute.MAIN) }
    var busy by remember { mutableStateOf(false) }
    var confirmingSignOut by remember { mutableStateOf(false) }
    var confirmingDelete by remember { mutableStateOf(false) }
    var hiddenUsers by remember { mutableStateOf<List<AccountService.HiddenUser>?>(null) }
    val scope = rememberCoroutineScope()
    var adminRoute by remember { mutableStateOf<AdminRoute>(AdminRoute.Moderators) }
    var contestRoute by remember { mutableStateOf<cz.slowdownradijo.app.contests.ContestAdminRoute>(cz.slowdownradijo.app.contests.ContestAdminRoute.List) }
    val runningContest by app.contests.current.collectAsStateWithLifecycle()
    var registerReason by remember { mutableStateOf<String?>(null) }
    var registerEmail by remember { mutableStateOf(false) }
    val statsVersion by app.stats.version.collectAsStateWithLifecycle()
    val slowride = remember(statsVersion) {
        val summary = app.stats.summary()
        SlowrideStats(summary.totalSeconds, summary.shows.take(3))
    }

    LaunchedEffect(Unit) { account.refresh() }
    BackHandler(route != ProfileRoute.MAIN) { route = ProfileRoute.MAIN }

    val actions = signInActions(context, scope, account, setBusy = { busy = it }, onEmail = { route = ProfileRoute.EMAIL }).copy(
        onNickname = { route = ProfileRoute.NICKNAME },
        onOpenStats = onOpenStats,
        onHiddenUsers = {
            hiddenUsers = null
            route = ProfileRoute.HIDDEN
            scope.launch { hiddenUsers = runCatching { account.hiddenUsers() }.getOrDefault(emptyList()) }
        },
        onRules = { route = ProfileRoute.RULES },
        onPrivacy = { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY))) } },
        onSignOut = { confirmingSignOut = true },
        onDeleteAccount = { confirmingDelete = true },
        onRegister = { reason ->
            account.registrationSource = reason
            app.analytics.track(cz.slowdownradijo.app.analytics.AnalyticsEvent.RegistrationPromptShown(reason))
            registerEmail = false
            registerReason = reason
        },
        onAdminModerators = { adminRoute = AdminRoute.Moderators; route = ProfileRoute.ADMIN },
        onAdminAdmins = { adminRoute = AdminRoute.Admins; route = ProfileRoute.ADMIN },
        onAdminContests = { contestRoute = cz.slowdownradijo.app.contests.ContestAdminRoute.List; route = ProfileRoute.CONTESTS },
        contestRunning = runningContest?.isRunning() == true,
    )
    LaunchedEffect(state) { if (state is AccountService.State.SignedIn) registerReason = null }
    BackHandler(route == ProfileRoute.ADMIN) {
        adminRoute = when (adminRoute) {
            is AdminRoute.Invite, is AdminRoute.InviteReady, is AdminRoute.Moderator -> AdminRoute.Moderators
            AdminRoute.AddAdmin -> AdminRoute.Admins
            else -> { route = ProfileRoute.MAIN; adminRoute }
        }
    }

    BackHandler(route == ProfileRoute.CONTESTS) {
        if (contestRoute == cz.slowdownradijo.app.contests.ContestAdminRoute.List) route = ProfileRoute.MAIN
        else contestRoute = cz.slowdownradijo.app.contests.ContestAdminRoute.List
    }

    fun toast(text: String) = ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, text))

    when (route) {
        ProfileRoute.MAIN -> Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)
        ) {
            Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            AppHeader(hostedShowOnAir = onAir.show?.hostName != null, onMenu = onOpenMenu)
            Box(Modifier.padding(top = Theme.Spacing.md, bottom = 36.dp)) {
                ProfileContent(state, busy, actions, stats = slowride)
            }
        }
        ProfileRoute.ADMIN -> AdminFlow(adminRoute) { next -> if (next == null) route = ProfileRoute.MAIN else adminRoute = next }
        ProfileRoute.CONTESTS -> cz.slowdownradijo.app.contests.ContestAdminFlow(contestRoute) { next ->
            if (next == null) route = ProfileRoute.MAIN else contestRoute = next
        }
        ProfileRoute.EMAIL -> EmailSignInScreen(
            sendCode = account::sendEmailCode,
            verify = account::verifyEmailCode,
            back = { route = ProfileRoute.MAIN },
            onSignedIn = { route = ProfileRoute.MAIN },
        )
        ProfileRoute.NICKNAME -> NicknameEditScreen(account.me, actions, back = {
            route = ProfileRoute.MAIN
            scope.launch { account.refresh() }
        })
        ProfileRoute.HIDDEN -> HiddenUsersScreen(
            hiddenUsers,
            onShow = { user ->
                scope.launch {
                    try {
                        account.unhide(user.userId)
                        hiddenUsers = hiddenUsers?.filterNot { it.userId == user.userId }
                    } catch (e: AccountError) {
                        toast(context.getString(e.messageRes))
                    }
                }
            },
            back = { route = ProfileRoute.MAIN },
        )
        ProfileRoute.RULES -> ChatRulesScreen(back = { route = ProfileRoute.MAIN })
    }

    registerReason?.let { reason ->
        RegisterSheet(reason, account.me?.nickname.orEmpty(), busy, registerEmail, actions.copy(onEmail = { registerEmail = true }),
            onBackFromEmail = { registerEmail = false }, onDismiss = { registerReason = null })
    }
    if (confirmingSignOut) {
        ConfirmDialog(
            stringResource(R.string.signOutConfirmTitle), stringResource(R.string.signOutConfirmBody),
            stringResource(R.string.profileSignOut), destructive = true, onDismiss = { confirmingSignOut = false },
        ) {
            confirmingSignOut = false
            scope.launch { account.signOut() }
        }
    }
    if (confirmingDelete) {
        ConfirmDialog(
            stringResource(if (account.isRegistered) R.string.deleteAccountConfirmTitle else R.string.deleteDataConfirmTitle),
            stringResource(if (account.isRegistered) R.string.deleteAccountConfirmBody else R.string.deleteDataConfirmBody),
            stringResource(R.string.profileDeleteAccount), destructive = true, onDismiss = { confirmingDelete = false },
        ) {
            confirmingDelete = false
            scope.launch {
                try {
                    val registered = account.isRegistered
                    account.deleteAccount()
                    app.analytics.track(cz.slowdownradijo.app.analytics.AnalyticsEvent.AccountDeleted(registered))
                } catch (e: AccountError) {
                    toast(context.getString(e.messageRes))
                }
            }
        }
    }
}

/**
 * Signing in with Apple, Google or e-mail and choosing the nickname, as the Profil tab
 * and the chat's "Připoj se do chatu" sheet both do it.
 */
fun signInActions(
    context: Context,
    scope: CoroutineScope,
    account: AccountService,
    setBusy: (Boolean) -> Unit,
    onEmail: () -> Unit,
): ProfileActions {
    fun toast(text: String) = ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, text))

    fun signIn(provider: String, block: suspend () -> Unit) {
        setBusy(true)
        scope.launch {
            try {
                block()
            } catch (e: AccountError) {
                when (e) {
                    AccountError.Cancelled -> Unit
                    AccountError.ProviderUnavailable, AccountError.Offline -> toast(context.getString(e.messageRes))
                    else -> toast(context.getString(R.string.signInFailed, provider))
                }
            } finally {
                setBusy(false)
            }
        }
    }

    return ProfileActions(
        onApple = { signIn("Apple") { account.signInWithApple() } },
        onGoogle = {
            val activity = context.findActivity()
            if (activity != null) signIn("Google") { account.signInWithGoogle(activity) }
        },
        onEmail = onEmail,
        checkNickname = { runCatching { account.checkNickname(it) }.getOrNull() },
        saveNickname = { nickname ->
            try {
                account.setNickname(nickname)
                null
            } catch (e: AccountError) {
                if (e.asNicknameStatus() == null) toast(context.getString(e.messageRes))
                e
            }
        },
    )
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** "Přezdívku změníš s účtem" / the Slowrider card's sign-up (Figma Profil M8). */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun RegisterSheet(
    reason: String,
    nickname: String,
    busy: Boolean,
    email: Boolean,
    actions: ProfileActions,
    onBackFromEmail: () -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = androidx.compose.foundation.shape.RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        if (email) {
            Box(Modifier.fillMaxHeight(0.9f).imePadding()) {
                EmailSignInScreen(
                    sendCode = context.app.account::sendEmailCode,
                    verify = context.app.account::verifyEmailCode,
                    back = onBackFromEmail,
                    onSignedIn = onBackFromEmail,
                )
            }
        } else {
            RegisterContent(reason, nickname, busy, actions, onDismiss)
        }
    }
}
