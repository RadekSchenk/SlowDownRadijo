package cz.slowdownradijo.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.contests.ContestAdmin
import cz.slowdownradijo.app.contests.ContestAdminDetail
import cz.slowdownradijo.app.contests.ContestAdminList
import cz.slowdownradijo.app.contests.ContestAdminNew
import cz.slowdownradijo.app.contests.ContestContent
import cz.slowdownradijo.app.contests.ContestDemo
import cz.slowdownradijo.app.contests.ContestForm
import cz.slowdownradijo.app.contests.ContestInfobox
import cz.slowdownradijo.app.contests.ContestLaunchConfirmation
import cz.slowdownradijo.app.contests.ContestPageActions
import cz.slowdownradijo.app.contests.ContestPageState
import cz.slowdownradijo.app.contests.ContestService
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/** The contest screens (Figma page "Soutěže"), on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class ContestScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val now = Instant.parse("2026-11-21T12:00:00Z")
    private val contest = ContestDemo.contest(now = now)

    private fun capture(name: String, language: AppLanguage = AppLanguage.CS, tall: Boolean = false, content: @Composable () -> Unit) {
        if (tall) org.robolectric.RuntimeEnvironment.setQualifiers("+h1500dp")
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) {
                    SlowDownTheme {
                        Box(Modifier.fillMaxSize().background(Theme.background)) { content() }
                    }
                }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    private fun page(name: String, page: ContestPageState, form: ContestForm = ContestForm(), language: AppLanguage = AppLanguage.CS, c: ContestService.Contest = contest) =
        capture(name, language, tall = true) { ContestContent(c, page, form, ContestPageActions()) }

    private fun admin(name: String, content: @Composable () -> Unit) = capture(name, tall = true) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(Theme.Spacing.lg)) { content() }
    }

    @Test fun infobox() = capture("contest_infobox_cs") { Box(Modifier.padding(20.dp)) { ContestInfobox(contest, {}, {}) } }

    @Test fun infoboxEnglish() = capture("contest_infobox_en", AppLanguage.EN) {
        Box(Modifier.padding(20.dp)) { ContestInfobox(ContestDemo.contest(english = true, now = now), {}, {}) }
    }

    @Test fun gate() = page("contest_gate_cs", ContestPageState.Gate)

    @Test fun formEmpty() = page("contest_form_empty_cs", ContestPageState.Form)

    @Test fun formFilled() = page("contest_form_filled_cs", ContestPageState.Form, ContestForm(selected = "B", phone = "+420 777 123 456"))

    @Test fun formErrors() = page("contest_form_errors_cs", ContestPageState.Form, ContestForm(phone = "777 12", showsErrors = true))

    @Test fun formText() = page(
        "contest_form_text_cs", ContestPageState.Form, ContestForm(answer = "Diggin' Time"),
        c = contest.copy(answerType = "text", options = emptyList()),
    )

    @Test fun sending() = page("contest_sending_cs", ContestPageState.Form, ContestForm(selected = "B", phone = "777123456", sending = true))

    @Test fun sendFailed() = page("contest_send_failed_cs", ContestPageState.Form, ContestForm(selected = "B", phone = "777123456", sendFailed = true))

    @Test fun sent() = page("contest_sent_cs", ContestPageState.Sent(ContestService.Entry("B", "+420777123456", now.toString())))

    @Test fun entered() = page("contest_entered_en", ContestPageState.Entered(ContestService.Entry("B", "+420777123456", now.toString())), language = AppLanguage.EN)

    @Test fun ended() = page("contest_ended_cs", ContestPageState.Ended)

    @Test fun adminList() = admin("admin_contests_cs") { ContestAdminList(ContestDemo.overview(now), {}, {}, {}) }

    @Test fun adminNone() = admin("admin_contests_none_cs") {
        ContestAdminList(ContestDemo.overview(now).copy(current = null), {}, {}, {})
    }

    @Test fun adminNewErrors() = admin("admin_contest_new_errors_cs") {
        ContestAdminNew(ContestAdmin.Draft(title = "Vyhraj lístky", endsAt = now), showsErrors = true, working = false, onDraft = {}, onPickEnd = {}, onReview = {})
    }

    @Test fun adminLaunch() = capture("admin_contest_launch_cs") {
        ContestLaunchConfirmation(
            ContestAdmin.Draft(title = contest.title, endsAt = contest.endsAt), working = false, onLaunch = {}, onEdit = {},
        )
    }

    @Test fun adminDetail() = admin("admin_contest_detail_cs") {
        ContestAdminDetail(ContestDemo.detail(drawn = false, now = now), drawing = false, onDraw = {}, onExport = {}, onPhone = { _, _ -> })
    }

    @Test fun adminWinners() = admin("admin_contest_winners_cs") {
        ContestAdminDetail(ContestDemo.detail(drawn = true, now = now), drawing = false, onDraw = {}, onExport = {}, onPhone = { _, _ -> })
    }
}
