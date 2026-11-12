package cz.slowdownradijo.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import cz.slowdownradijo.app.feedback.FeedbackForm
import cz.slowdownradijo.app.feedback.FeedbackScreen
import cz.slowdownradijo.app.home.AnalyticsConsentCard
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.message.MessageActions
import cz.slowdownradijo.app.message.MessageContent
import cz.slowdownradijo.app.message.MessageUi
import cz.slowdownradijo.app.message.VoiceMessageState
import cz.slowdownradijo.app.news.NewsDetailScreen
import cz.slowdownradijo.app.news.NewsListScreen
import cz.slowdownradijo.app.news.NewsService
import cz.slowdownradijo.app.news.NewsStore
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

/** Vzkaz, Novinky, Zpětná vazba and the consent card, on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class FeaturesScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun capture(name: String, language: AppLanguage = AppLanguage.CS, content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) {
                    SlowDownTheme { Box(Modifier.fillMaxSize().background(Theme.background)) { content() } }
                }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    private val levels = listOf(0.35f, 0.7f, 0.55f, 0.9f, 0.6f, 0.8f, 0.45f, 0.95f, 0.65f, 0.5f, 0.85f, 0.4f, 0.75f) + List(5) { 0f }

    @Composable
    private fun message(ui: MessageUi) = Column(Modifier.padding(20.dp)) { MessageContent(ui, MessageActions()) }

    @Test fun messageReady() = capture("message_ready_cs") { message(MessageUi(VoiceMessageState.Ready)) }

    @Test fun messageRecording() = capture("message_recording_cs") { message(MessageUi(VoiceMessageState.Recording, elapsed = 23.4, levels = levels)) }

    @Test fun messageRecorded() = capture("message_recorded_cs") {
        message(MessageUi(VoiceMessageState.Recorded(File("x.m4a"), 38.0), levels = levels, isPlaying = true, playbackProgress = 0.55))
    }

    @Test fun messageSentEnglish() = capture("message_sent_en", AppLanguage.EN) { message(MessageUi(VoiceMessageState.Sent)) }

    private val posts = NewsService.parse(javaClass.classLoader!!.getResource("web/posts.json")!!.readText())

    @Test fun newsList() = capture("news_cs") { NewsListScreen(NewsStore.State.Loaded(posts), true, {}, {}, {}) }

    @Test fun newsDetail() = capture("news_detail_cs") { NewsDetailScreen(posts[2], {}) }

    @Test fun feedback() = capture("feedback_cs") { FeedbackScreen("Super appka, jen bych chtěl…", FeedbackForm.State.FAILED, {}, {}, {}, {}) }

    @Test fun consentCard() = capture("consent_card_cs") { Box(Modifier.padding(20.dp)) { AnalyticsConsentCard({}) } }
}
