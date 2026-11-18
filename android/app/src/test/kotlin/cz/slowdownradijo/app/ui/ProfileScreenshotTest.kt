package cz.slowdownradijo.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.account.AccountService.SignInMethod
import cz.slowdownradijo.app.account.AccountService.State
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.profile.ChatRulesScreen
import cz.slowdownradijo.app.profile.EmailSignInScreen
import cz.slowdownradijo.app.profile.HiddenUsersScreen
import cz.slowdownradijo.app.profile.NicknameEditScreen
import cz.slowdownradijo.app.profile.NicknameSetup
import cz.slowdownradijo.app.profile.NicknameStatus
import cz.slowdownradijo.app.profile.ProfileActions
import cz.slowdownradijo.app.profile.ProfileContent
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/** The Profil tab's states (Figma page "Profil"), on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class ProfileScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val now = Instant.parse("2026-11-18T14:30:00Z")
    private val listener = AccountService.Me(userId = "u1", nickname = "vinylovy_tom")

    private fun capture(name: String, language: AppLanguage = AppLanguage.CS, padded: Boolean = true, content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) {
                    SlowDownTheme {
                        Box(Modifier.fillMaxSize().background(Theme.background).then(if (padded) Modifier.padding(20.dp) else Modifier)) { content() }
                    }
                }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    @Test fun signedOut() = capture("profile_signed_out_cs") { ProfileContent(State.SignedOut, busy = false, ProfileActions(), now) }

    @Test fun signedOutEnglish() = capture("profile_signed_out_en", AppLanguage.EN) { ProfileContent(State.SignedOut, busy = false, ProfileActions(), now) }

    @Test fun signedIn() = capture("profile_signed_in_cs") {
        ProfileContent(State.SignedIn(SignInMethod.APPLE, "tom@example.cz", listener), busy = false, ProfileActions(), now)
    }

    @Test fun host() = capture("profile_dj_cs") {
        ProfileContent(State.SignedIn(SignInMethod.GOOGLE, null, AccountService.Me(userId = "d", hostId = "dj-pufaz", hostName = "DJ Pufaz", role = "dj", isModerator = true)), busy = false, ProfileActions(), now)
    }

    @Test fun muted() = capture("profile_muted_cs") {
        ProfileContent(State.SignedIn(SignInMethod.EMAIL, "tom@example.cz", listener.copy(mutedUntilText = "2026-11-19T07:04:00+00:00")), busy = false, ProfileActions(), now)
    }

    @Test fun nicknameSetupTaken() = capture("profile_nickname_setup_cs") {
        NicknameSetup(ProfileActions(), initial = "Vinylovy_Tom", initialStatus = NicknameStatus.TAKEN)
    }

    @Test fun nicknameCooldown() = capture("profile_nickname_cooldown_cs", padded = false) {
        NicknameEditScreen(listener.copy(nicknameNextChangeAtText = "2026-11-19T07:04:00+00:00"), ProfileActions(), back = {}, now = now)
    }

    @Test fun emailCodeInvalid() = capture("profile_email_code_cs", padded = false) {
        EmailSignInScreen(
            sendCode = { AccountService.EmailCodeRequest(it, false) },
            verify = { _, _ -> },
            back = {}, onSignedIn = {},
            initialRequest = AccountService.EmailCodeRequest("tom@example.cz", false),
            initialCode = "481902", initialCodeInvalid = true,
        )
    }

    @Test fun hiddenUsers() = capture("profile_hidden_users_cs", padded = false) {
        HiddenUsersScreen(listOf(AccountService.HiddenUser("x", "brancikovac")), onShow = {}, back = {})
    }

    @Test fun rules() = capture("profile_rules_cs", padded = false) { ChatRulesScreen(back = {}) }
}
