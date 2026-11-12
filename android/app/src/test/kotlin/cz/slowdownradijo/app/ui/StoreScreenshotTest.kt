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
import cz.slowdownradijo.app.home.AppHeader
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeProgramSection
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.OnAir
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.menu.HubRoot
import cz.slowdownradijo.app.message.MessageActions
import cz.slowdownradijo.app.message.MessageContent
import cz.slowdownradijo.app.message.MessageUi
import cz.slowdownradijo.app.message.VoiceMessageState
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.stats.StatsContent
import cz.slowdownradijo.app.stats.StatsSummary
import cz.slowdownradijo.app.stats.StatsUi
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

/**
 * Phone screenshots for the Google Play listing (`docs/google-play.md`),
 * in Czech and English, written to `android/store/screenshots/`. A
 * Pixel 7's width at 9:16, which is all Play takes; tools/android/store_graphics.py
 * then brings them to exactly 1080 x 1920.
 *
 *     ./gradlew :app:testDebugUnitTest --tests '*StoreScreenshotTest*' -Proborazzi.test.record=true
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h731dp-normal-notlong-notround-any-420dpi-keyshidden-nonav")
class StoreScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    /** Monday 9 Nov 2026, 13:30 in Prague: Show podle Majkla, hosted. */
    private val now = Instant.parse("2026-11-09T12:30:00Z")
    private val show = store.currentShow(now)!!
    private val onAir = OnAir(
        show = show,
        progress = store.progress(show, now),
        showEnd = store.endDate(show, now),
        showStart = store.startDate(show, now),
        verifiedTrack = NowPlayingTrack("Khruangbin", "Maria También"),
    )

    private fun capture(name: String, language: AppLanguage, content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) { SlowDownTheme { content() } }
            }
        }
        compose.onRoot().captureRoboImage("../store/screenshots/${language.code}/$name.png")
    }

    /** A tab's page as the app lays it out: the header, then the content. */
    @Composable
    private fun tabPage(content: @Composable () -> Unit) {
        Column(Modifier.fillMaxSize().background(Theme.background).padding(horizontal = 20.dp)) {
            AppHeader(hostedShowOnAir = true, onMenu = {})
            Box(Modifier.padding(top = Theme.Spacing.md)) { content() }
        }
    }

    private fun home(language: AppLanguage) = capture("1_home", language) {
        RootScreen(Tab.RADIO, {}, menuOpen = false, menu = {}) {
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, now.plus(Duration.ofMinutes(25)), now), HomeActions()) {
                HomeProgramSection(store.days.value, show, now, followed = setOf("bass-time", "groove-lab-s-don-hoblinon"), onBell = {}, modifier = Modifier.padding(top = 32.dp))
            }
        }
    }

    private fun programme(language: AppLanguage) = capture("2_programme", language) {
        RootScreen(Tab.RADIO, {}, menuOpen = false, menu = {}) {
            tabPage {
                HomeProgramSection(store.days.value, show, now, followed = setOf("bass-time", "groove-lab-s-don-hoblinon"), onBell = {})
            }
        }
    }

    private val summary = StatsSummary(
        todaySeconds = 2 * 3600 + 17 * 60, totalSeconds = 3 * 86400 + 4 * 3600 + 5 * 60, communitySeconds = 412 * 3600,
        rank = 7, rankedListeners = 128,
        bars = listOf(1800, 0, 5400, 3600, 7200, 900, 8220).mapIndexed { i, s ->
            StatsSummary.DayBar("2026-11-0${3 + i}", (i + 3) % 7 + 1, s, s == 8220)
        },
        weekSeconds = 27_120, weekStart = LocalDate.parse("2026-11-03"), weekEnd = LocalDate.parse("2026-11-09"),
        shows = listOf(
            StatsSummary.ShowShare("show-podle-majkla", "Show podle Majkla", "Vrtulník Michael V.", null, null, 40_000, 0.42),
            StatsSummary.ShowShare("beat-brunch-s-jaro-cossiga", "Beat Brunch", "Jaro Cossiga", null, null, 30_000, 0.31),
            StatsSummary.ShowShare("morning-coffee-s-dj-pufaz", "Morning Coffee", "DJ Pufaz", null, null, 25_000, 0.27),
        ),
        showsSeconds = 95_000,
    )

    private fun stats(language: AppLanguage) = capture("3_stats", language) {
        RootScreen(Tab.STATS, {}, menuOpen = false, menu = {}) {
            tabPage { StatsContent(StatsUi(summary, enabled = true, measuring = true, communityUnlocked = true, loadFailed = false), {}, {}) }
        }
    }

    private val levels = listOf(0.35f, 0.7f, 0.55f, 0.9f, 0.6f, 0.8f, 0.45f, 0.95f, 0.65f, 0.5f, 0.85f, 0.4f, 0.75f, 0.6f, 0.7f, 0.5f, 0.8f, 0.45f)

    private fun message(language: AppLanguage) = capture("4_message", language) {
        RootScreen(Tab.MESSAGE, {}, menuOpen = false, menu = {}) {
            tabPage {
                MessageContent(
                    MessageUi(VoiceMessageState.Recorded(File("x.m4a"), 38.0), levels = levels, isPlaying = true, playbackProgress = 0.55),
                    MessageActions(),
                )
            }
        }
    }

    private fun menu(language: AppLanguage) = capture("5_menu", language) {
        Box(Modifier.fillMaxSize().background(Theme.background)) { HubRoot({}, {}, {}) }
    }

    @Test fun homeCs() = home(AppLanguage.CS)
    @Test fun programmeCs() = programme(AppLanguage.CS)
    @Test fun statsCs() = stats(AppLanguage.CS)
    @Test fun messageCs() = message(AppLanguage.CS)
    @Test fun menuCs() = menu(AppLanguage.CS)

    @Test fun homeEn() = home(AppLanguage.EN)
    @Test fun programmeEn() = programme(AppLanguage.EN)
    @Test fun statsEn() = stats(AppLanguage.EN)
    @Test fun messageEn() = message(AppLanguage.EN)
    @Test fun menuEn() = menu(AppLanguage.EN)
}
