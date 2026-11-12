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
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.RootScreen
import cz.slowdownradijo.app.Tab
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeProgramSection
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.OnAir
import cz.slowdownradijo.app.home.SleepTimerSheetContent
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.menu.HubRoot
import cz.slowdownradijo.app.message.MessageActions
import cz.slowdownradijo.app.message.MessageContent
import cz.slowdownradijo.app.message.MessageUi
import cz.slowdownradijo.app.message.VoiceMessageState
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Instant

/**
 * The tightest cases: a small phone (360 × 640 dp, as the smallest common
 * Androids) at the normal text size, and a usual phone at the largest
 * text size Android offers (200 %).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenSizesScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    private val now = Instant.parse("2026-11-09T12:30:00Z")

    private fun capture(name: String, fontScale: Float = 1f, content: @Composable () -> Unit) {
        RuntimeEnvironment.setFontScale(fontScale)
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(AppLanguage.CS) {
                    SlowDownTheme { Box(Modifier.fillMaxSize().background(Theme.background)) { content() } }
                }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    @Composable
    private fun home() {
        val show = store.currentShow(now)!!
        val onAir = OnAir(show, store.progress(show, now), store.endDate(show, now), store.startDate(show, now), NowPlayingTrack("Khruangbin", "Maria También"))
        RootScreen(Tab.RADIO, {}, false, {}) {
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, now.plusSeconds(4000), now), HomeActions()) {
                HomeProgramSection(store.days.value, show, now, emptySet(), {}, Modifier.padding(top = 32.dp))
            }
        }
    }

    @Composable
    private fun message() = Column(Modifier.padding(20.dp)) {
        MessageContent(MessageUi(VoiceMessageState.Recorded(File("x"), 38.0)), MessageActions())
    }

    @Composable
    private fun sleep() = SleepTimerSheetContent(null, now.plusSeconds(596), store.endDate(store.currentShow(now)!!, now), now, {}, {})

    @Test @Config(qualifiers = "w360dp-h640dp-xhdpi") fun smallHome() = capture("small_home", content = { home() })
    @Test @Config(qualifiers = "w360dp-h640dp-xhdpi") fun smallMenu() = capture("small_menu", content = { HubRoot({}, {}, {}) })
    @Test @Config(qualifiers = "w360dp-h640dp-xhdpi") fun smallSleepTimer() = capture("small_sleep_timer", content = { sleep() })

    @Test @Config(qualifiers = "w411dp-h891dp-xxhdpi") fun largeTextHome() = capture("large_text_home", 2f) { home() }
    @Test @Config(qualifiers = "w411dp-h891dp-xxhdpi") fun largeTextMessage() = capture("large_text_message", 2f) { message() }
    @Test @Config(qualifiers = "w411dp-h891dp-xxhdpi") fun largeTextSleepTimer() = capture("large_text_sleep_timer", 2f) { sleep() }
    @Test @Config(qualifiers = "w411dp-h891dp-xxhdpi") fun largeTextMenu() = capture("large_text_menu", 2f) { HubRoot({}, {}, {}) }
}
