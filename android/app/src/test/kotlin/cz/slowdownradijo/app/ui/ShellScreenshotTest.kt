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
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.RootScreen
import cz.slowdownradijo.app.Tab
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeProgramSection
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.OnAir
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.menu.HubRoot
import cz.slowdownradijo.app.menu.SettingsActions
import cz.slowdownradijo.app.menu.SettingsScreen
import cz.slowdownradijo.app.menu.SettingsUi
import cz.slowdownradijo.app.menu.ShowRemindersScreen
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import cz.slowdownradijo.app.stats.StatsContent
import cz.slowdownradijo.app.stats.StatsHomeBlock
import cz.slowdownradijo.app.stats.StatsSummary
import cz.slowdownradijo.app.stats.StatsUi
import androidx.compose.foundation.verticalScroll
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Instant

/** The app's frame and the menu's pages, on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class ShellScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    /** Monday 9 Nov 2026, 10:15 in Prague: Beat Brunch. */
    private val now = Instant.parse("2026-11-09T09:15:00Z")

    private fun capture(name: String, language: AppLanguage = AppLanguage.CS, content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) { SlowDownTheme { content() } }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    private fun page(content: @Composable () -> Unit) = @Composable {
        Box(Modifier.fillMaxSize().background(Theme.background)) { content() }
    }

    @Test fun homeWithProgrammeAndTabs() = capture("root_home_cs") {
        val show = store.currentShow(now)!!
        val onAir = OnAir(show, store.progress(show, now), store.endDate(show, now), store.startDate(show, now))
        RootScreen(Tab.RADIO, {}, menuOpen = false, menu = {}) {
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, null, now), HomeActions()) {
                HomeProgramSection(store.days.value, show, now, followed = setOf("bass-time"), onBell = {}, modifier = Modifier.padding(top = 32.dp))
            }
        }
    }

    @Test fun programmeOnly() = capture("programme_cs") {
        page {
            Box(Modifier.padding(horizontal = 20.dp)) {
                HomeProgramSection(store.days.value, store.currentShow(now), now, followed = emptySet(), onBell = {})
            }
        }()
    }

    private val summary = StatsSummary(
        todaySeconds = 2 * 3600 + 17 * 60, totalSeconds = 3 * 86400 + 4 * 3600 + 5 * 60, communitySeconds = 412 * 3600,
        rank = 7, rankedListeners = 128,
        bars = listOf(1800, 0, 5400, 3600, 7200, 900, 8220).mapIndexed { i, s ->
            StatsSummary.DayBar("2026-11-0${4 + i}", (i + 3) % 7 + 1, s, s == 8220)
        },
        weekSeconds = 27_120, weekStart = java.time.LocalDate.parse("2026-11-04"), weekEnd = java.time.LocalDate.parse("2026-11-10"),
        shows = listOf(
            StatsSummary.ShowShare("beat-brunch", "Beat Brunch", "Jaro Cossiga", null, null, 40_000, 0.42),
            StatsSummary.ShowShare("bass-time", "Bass Time", "Jaro Cossiga", null, null, 30_000, 0.31),
            StatsSummary.ShowShare("x", null, null, null, null, 25_000, 0.27),
        ),
        showsSeconds = 95_000,
    )

    @Test fun stats() = capture("stats_cs") {
        page {
            androidx.compose.foundation.layout.Column(Modifier.verticalScroll(androidx.compose.foundation.rememberScrollState()).padding(horizontal = 20.dp)) {
                StatsContent(StatsUi(summary, enabled = true, measuring = true, communityUnlocked = true, loadFailed = false), {}, {})
            }
        }()
    }

    @Test fun statsDisabledEnglish() = capture("stats_disabled_en", AppLanguage.EN) {
        page {
            Box(Modifier.padding(horizontal = 20.dp)) {
                StatsContent(StatsUi(StatsSummary(), enabled = false, measuring = false, communityUnlocked = false, loadFailed = false), {}, {})
            }
        }()
    }

    @Test fun statsHomeBlock() = capture("stats_home_block_cs") {
        page { Box(Modifier.padding(20.dp)) { StatsHomeBlock(StatsUi(summary, true, true, true, false), {}) } }()
    }

    @Test fun menu() = capture("menu_cs") { page { HubRoot({}, {}, {}) }() }

    @Test fun menuEnglish() = capture("menu_en", AppLanguage.EN) { page { HubRoot({}, {}, {}) }() }

    @Test fun settings() = capture("settings_cs") {
        page { SettingsScreen(SettingsUi(autoplay = true, remindersCount = 2, statsEnabled = true, analyticsEnabled = false), SettingsActions(), {}, {}) }()
    }

    @Test fun showReminders() = capture("show_reminders_cs") {
        val shows = store.catalog.sortedBy { it.displayTitle.lowercase() }
        page { ShowRemindersScreen(shows, setOf(shows[1].id), notificationsBlocked = true, onToggle = { _, _ -> }, onUnfollowAll = {}, back = {}) }()
    }
}

private val Int.dp get() = androidx.compose.ui.unit.Dp(this.toFloat())
