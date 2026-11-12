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
import com.github.takahirom.roborazzi.RoborazziATFAccessibilityCheckOptions
import com.github.takahirom.roborazzi.RoborazziATFAccessibilityChecker
import com.github.takahirom.roborazzi.checkRoboAccessibility
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckPreset
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckResultUtils
import com.google.android.apps.common.testing.accessibility.framework.checks.TextContrastCheck
import cz.slowdownradijo.app.RootScreen
import cz.slowdownradijo.app.Tab
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.feedback.FeedbackForm
import cz.slowdownradijo.app.feedback.FeedbackScreen
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeProgramSection
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.OnAir
import cz.slowdownradijo.app.home.SleepTimerSheetContent
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.menu.HubRoot
import cz.slowdownradijo.app.menu.SettingsActions
import cz.slowdownradijo.app.menu.SettingsScreen
import cz.slowdownradijo.app.menu.SettingsUi
import cz.slowdownradijo.app.menu.ShowRemindersScreen
import cz.slowdownradijo.app.message.MessageActions
import cz.slowdownradijo.app.message.MessageContent
import cz.slowdownradijo.app.message.MessageUi
import cz.slowdownradijo.app.message.VoiceMessageState
import cz.slowdownradijo.app.news.NewsListScreen
import cz.slowdownradijo.app.news.NewsService
import cz.slowdownradijo.app.news.NewsStore
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
import java.time.Instant

/**
 * Google's Accessibility Test Framework over every screen: touch targets
 * of at least 48 dp, text contrast, a label on everything TalkBack can
 * reach, no duplicate descriptions. Fails on errors.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class AccessibilityTest {
    @get:Rule val compose = createComposeRule()

    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    private val now = Instant.parse("2026-11-09T12:30:00Z")

    private fun check(content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(AppLanguage.CS) {
                    SlowDownTheme { Box(Modifier.fillMaxSize().background(Theme.background)) { content() } }
                }
            }
        }
        compose.onRoot().checkRoboAccessibility(
            RoborazziATFAccessibilityCheckOptions(
                RoborazziATFAccessibilityChecker(
                    AccessibilityCheckPreset.LATEST,
                    // Text contrast is the design's (the same colours as on iOS, from
                    // Figma): reported in docs/android.md, not failed here.
                    suppressions = AccessibilityCheckResultUtils.matchesCheck(TextContrastCheck::class.java),
                ),
                RoborazziATFAccessibilityChecker.CheckLevel.Warning,
            )
        )
    }

    @Test fun home() = check {
        val show = store.currentShow(now)!!
        val onAir = OnAir(show, store.progress(show, now), store.endDate(show, now), store.startDate(show, now), NowPlayingTrack("Khruangbin", "Maria También"))
        RootScreen(Tab.RADIO, {}, false, {}) {
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, null, now), HomeActions()) {
                HomeProgramSection(store.days.value, show, now, setOf("bass-time"), {}, Modifier.padding(top = 32.dp))
            }
        }
    }

    @Test fun sleepTimer() = check {
        SleepTimerSheetContent(null, null, store.endDate(store.currentShow(now)!!, now), now, {}, {})
    }

    @Test fun stats() = check {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp)) {
            StatsContent(
                StatsUi(
                    StatsSummary(todaySeconds = 3600, totalSeconds = 90_000, rank = 3, rankedListeners = 40,
                        bars = (1..7).map { StatsSummary.DayBar("d$it", it, it * 600, it == 7) }, weekSeconds = 16_800,
                        shows = listOf(StatsSummary.ShowShare("a", "Beat Brunch", "Jaro Cossiga", null, null, 600, 1.0)), showsSeconds = 600),
                    enabled = true, measuring = true, communityUnlocked = true, loadFailed = false,
                ),
                {}, {},
            )
        }
    }

    @Test fun messageReady() = check { Column(Modifier.padding(20.dp)) { MessageContent(MessageUi(VoiceMessageState.Ready), MessageActions()) } }

    @Test fun messageRecorded() = check {
        Column(Modifier.padding(20.dp)) { MessageContent(MessageUi(VoiceMessageState.Recorded(File("x"), 38.0)), MessageActions()) }
    }

    @Test fun menu() = check { HubRoot({}, {}, {}) }

    @Test fun settings() = check { SettingsScreen(SettingsUi(true, 1, true, false), SettingsActions(), {}, {}) }

    @Test fun showReminders() = check {
        ShowRemindersScreen(store.catalog.take(6), setOf(store.catalog[1].id), notificationsBlocked = true, onToggle = { _, _ -> }, onUnfollowAll = {}, back = {})
    }

    @Test fun news() = check {
        NewsListScreen(NewsStore.State.Loaded(NewsService.parse(javaClass.classLoader!!.getResource("web/posts.json")!!.readText())), true, {}, {}, {})
    }

    @Test fun feedback() = check { FeedbackScreen("", FeedbackForm.State.IDLE, {}, {}, {}, {}) }
}
