package cz.slowdownradijo.app.profile

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
import kotlinx.coroutines.launch

private enum class ProfileRoute { MAIN, EMAIL, NICKNAME, HIDDEN, RULES }

private const val PRIVACY_POLICY = "https://slowdownradijo.cz/ochrana-osobnich-udaju/"

/** The Profil tab (`ProfileView.swift`): its page and the pages it pushes. */
@Composable
fun ProfilePage(onOpenMenu: () -> Unit) {
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

    LaunchedEffect(Unit) { account.refresh() }
    BackHandler(route != ProfileRoute.MAIN) { route = ProfileRoute.MAIN }

    fun toast(text: String) = ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, text))

    fun signIn(provider: String, block: suspend () -> Unit) {
        busy = true
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
                busy = false
            }
        }
    }

    val actions = ProfileActions(
        onApple = { signIn("Apple") { account.signInWithApple() } },
        onGoogle = {
            val activity = context.findActivity()
            if (activity != null) signIn("Google") { account.signInWithGoogle(activity) }
        },
        onEmail = { route = ProfileRoute.EMAIL },
        onNickname = { route = ProfileRoute.NICKNAME },
        onHiddenUsers = {
            hiddenUsers = null
            route = ProfileRoute.HIDDEN
            scope.launch { hiddenUsers = runCatching { account.hiddenUsers() }.getOrDefault(emptyList()) }
        },
        onRules = { route = ProfileRoute.RULES },
        onPrivacy = { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY))) } },
        onSignOut = { confirmingSignOut = true },
        onDeleteAccount = { confirmingDelete = true },
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

    when (route) {
        ProfileRoute.MAIN -> Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)
        ) {
            Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            AppHeader(hostedShowOnAir = onAir.show?.hostName != null, onMenu = onOpenMenu)
            Box(Modifier.padding(top = Theme.Spacing.md, bottom = 36.dp)) {
                ProfileContent(state, busy, actions)
            }
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
            stringResource(R.string.deleteAccountConfirmTitle), stringResource(R.string.deleteAccountConfirmBody),
            stringResource(R.string.profileDeleteAccount), destructive = true, onDismiss = { confirmingDelete = false },
        ) {
            confirmingDelete = false
            scope.launch {
                try {
                    account.deleteAccount()
                } catch (e: AccountError) {
                    toast(context.getString(e.messageRes))
                }
            }
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
