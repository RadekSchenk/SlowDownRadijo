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
import cz.slowdownradijo.app.chat.ChatContent
import cz.slowdownradijo.app.chat.ChatHomeSection
import cz.slowdownradijo.app.chat.ChatMessage
import cz.slowdownradijo.app.chat.ChatService
import cz.slowdownradijo.app.chat.ChatTimeline
import cz.slowdownradijo.app.chat.ChatWriter
import cz.slowdownradijo.app.chat.JoinButtons
import cz.slowdownradijo.app.chat.OutgoingChatMessage
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.profile.ProfileActions
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/** The chat (Figma page "Chat"): the home page section, the sheet and joining, on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class ChatScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val now = Instant.parse("2026-11-18T07:04:00Z") // 8:04 in Prague
    private val show = Show(id = "morning-coffee", name = "Morning Coffee", start = "07:00", end = "10:00", hostName = "DJ Pufaz")
    private val shows = mapOf("morning-coffee" to "07:00", "nocni-linka" to "22:00", "weekend-aftertaste" to "20:00")

    private fun msg(id: Long, minutesAgo: Long, name: String, body: String, role: String = "listener", show: String? = "morning-coffee", title: String? = "Morning Coffee") =
        ChatMessage(id, "u-$name", name, role, body, show, title, now.minusSeconds(minutesAgo * 60).toString())

    private val yesterday = listOf(
        msg(1, 12 * 60, "Jaromir99", "Dušičková neděle 👀", show = "weekend-aftertaste", title = "Weekend Aftertaste"),
        msg(2, 11 * 60 + 50, "brancikovac", "Anderson nikdy nezklame 🔥", show = "weekend-aftertaste", title = "Weekend Aftertaste"),
    )
    private val today = listOf(
        msg(3, 50, "nela", "Zdravím z ranní tramvaje 💜"),
        msg(4, 40, "karolina.pivnivila", "Výsadba nové chmelnice není jen tak. Jsou to hromady kořínků jako uschlé mandragory.", role = "supporter"),
        msg(5, 30, "DJ Pufaz", "Díky, že jste s námi. Ještě nekončíme!", role = "dj"),
        msg(6, 20, "nela", "🔥"), msg(7, 20, "marty", "🔥"), msg(8, 19, "tom", "🔥"), msg(9, 19, "jana", "🔥"),
        msg(10, 5, "marty", "Tenhle výběr dneska fakt sedí 🎧"),
    )
    private val pinned = msg(11, 60, "DJ Pufaz", "Dobré ráno! Co dnes posloucháte u kafe? ☕", role = "dj").copy(pinnedAtText = now.minusSeconds(3000).toString())

    private val listener = ChatWriter(signedIn = true, name = "vinylovy_tom", role = "listener", mutedUntil = null, blocked = false)
    private val signedOut = ChatWriter(signedIn = false, name = null, role = "listener", mutedUntil = null, blocked = false)

    private fun capture(name: String, language: AppLanguage = AppLanguage.CS, padded: Boolean = false, content: @Composable () -> Unit) {
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

    @Composable
    private fun sheet(state: ChatService.State, writer: ChatWriter, draft: String = "") = ChatContent(
        state = state, show = show, writer = writer, draft = draft, onDraft = {}, onSend = { _, _ -> }, onRetry = {},
        onClose = {}, onRules = {}, onSeen = {},
        showLabel = { id, title, _ -> id?.let { ChatTimeline.ShowLabel(shows[it], title ?: it) } },
        modifier = Modifier.fillMaxSize(), now = now,
    )

    @Test fun homeSection() = capture("chat_home_cs", padded = true) {
        ChatHomeSection(ChatService.State(messages = yesterday + today, loaded = true, lastSeenId = 10), onOpen = {}, onSeen = {}, now = now)
    }

    @Test fun homeSectionQuiet() = capture("chat_home_quiet_cs", padded = true) {
        ChatHomeSection(ChatService.State(messages = yesterday, pinned = pinned, loaded = true, lastSeenId = 2), onOpen = {}, onSeen = {}, now = now)
    }

    @Test fun sheetSignedIn() = capture("chat_sheet_cs") {
        sheet(ChatService.State(messages = yesterday + today, pinned = pinned, loaded = true), listener)
    }

    @Test fun sheetSignedOutEnglish() = capture("chat_sheet_signed_out_en", AppLanguage.EN) {
        sheet(ChatService.State(messages = yesterday + today, pinned = pinned, loaded = true), signedOut, draft = "This groove is on 🔥")
    }

    @Test fun sheetQuietToday() = capture("chat_sheet_quiet_cs") {
        sheet(ChatService.State(messages = yesterday, loaded = true), listener)
    }

    @Test fun sheetFirstMessageSent() = capture("chat_sheet_sent_cs") {
        sheet(
            ChatService.State(
                messages = yesterday, loaded = true,
                outgoing = listOf(
                    OutgoingChatMessage(id = "a", body = "Dobré ráno 👋", createdAt = now),
                    OutgoingChatMessage(id = "b", body = "Co to teď hrálo?", createdAt = now, failed = true),
                ),
                outgoingShow = "morning-coffee" to "Morning Coffee",
            ),
            listener,
        )
    }

    @Test fun sheetMuted() = capture("chat_sheet_muted_cs") {
        sheet(ChatService.State(messages = yesterday + today, loaded = true), listener.copy(mutedUntil = now.plusSeconds(24 * 3600)))
    }

    @Test fun join() = capture("chat_join_cs") {
        JoinButtons(busy = false, actions = ProfileActions(), onDismiss = {}, onRules = {})
    }

}
