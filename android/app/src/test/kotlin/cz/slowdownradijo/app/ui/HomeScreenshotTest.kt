package cz.slowdownradijo.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeRight
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.OnAir
import cz.slowdownradijo.app.home.SleepTimerOption
import cz.slowdownradijo.app.home.SleepTimerSheetContent
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.player.PlaybackState
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

/** The home header in its states, on a Pixel 7. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class HomeScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))

    private fun onAir(at: String, track: NowPlayingTrack? = null): Pair<OnAir, Instant> {
        val now = Instant.parse(at)
        val show = store.currentShow(now)!!
        return OnAir(
            show = show,
            progress = store.progress(show, now),
            showEnd = store.endDate(show, now),
            showStart = store.startDate(show, now),
            verifiedTrack = track,
        ) to now
    }

    private fun capture(name: String, language: AppLanguage, content: @Composable () -> Unit) {
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(language) { SlowDownTheme { content() } }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    /** Monday 13:30: Show podle Majkla, hosted, a song verified, playing, a sleep timer running. */
    @Test fun playingHostedShowWithSong() {
        val (onAir, now) = onAir("2026-11-09T12:30:00Z", NowPlayingTrack("Khruangbin", "Maria También"))
        capture("home_playing_cs", AppLanguage.CS) {
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, now.plus(Duration.ofSeconds(596)), now, cz.slowdownradijo.app.player.AudioOutputInfo("JBL Charge 3", "bluetooth", true)), HomeActions())
        }
    }

    /** The song line swiped back to the song before (`SongHistoryLine`). */
    @Test fun earlierSong() {
        val (onAir, now) = onAir("2026-11-09T12:30:00Z", NowPlayingTrack("Khruangbin", "Maria También"))
        val earlier = listOf(cz.slowdownradijo.app.data.RecentSong("Men I Trust", "Show Me How", now.minusSeconds(6 * 60)))
        compose.setContent {
            CompositionLocalProvider(LocalAnimationsEnabled provides false) {
                ProvideAppLanguage(AppLanguage.CS) { SlowDownTheme { HomeScreen(HomeUi(onAir, PlaybackState.Playing, null, now, earlierSongs = earlier), HomeActions()) } }
            }
        }
        compose.onNodeWithText("Khruangbin – Maria También").performTouchInput { swipeRight() }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("src/test/screenshots/home_earlier_song_cs.png")
    }

    /** Monday 01:00: the rotation, no host, paused, in English. */
    @Test fun pausedRotationEnglish() {
        val (onAir, now) = onAir("2026-11-09T00:00:00Z")
        capture("home_paused_en", AppLanguage.EN) {
            HomeScreen(HomeUi(onAir, PlaybackState.Paused, null, now), HomeActions())
        }
    }

    /** Beat Brunch, connecting. */
    @Test fun connecting() {
        val (onAir, now) = onAir("2026-11-09T09:15:00Z")
        capture("home_connecting_cs", AppLanguage.CS) {
            HomeScreen(HomeUi(onAir, PlaybackState.Connecting, null, now), HomeActions())
        }
    }

    @Test fun streamError() {
        val (onAir, now) = onAir("2026-11-09T09:15:00Z")
        capture("home_error_cs", AppLanguage.CS) {
            HomeScreen(HomeUi(onAir, PlaybackState.Error, null, now), HomeActions())
        }
    }

    @Test fun sleepTimerSheet() {
        val (onAir, now) = onAir("2026-11-09T12:30:00Z")
        capture("sleep_timer_running_cs", AppLanguage.CS) {
            Box(Modifier.background(Theme.statsCard)) {
                SleepTimerSheetContent(SleepTimerOption.MIN15, now.plus(Duration.ofSeconds(596)), onAir.showEnd, now, {}, {})
            }
        }
    }

    @Test fun sleepTimerSheetEnglish() {
        val (onAir, now) = onAir("2026-11-09T12:30:00Z")
        capture("sleep_timer_en", AppLanguage.EN) {
            Box(Modifier.background(Theme.statsCard)) {
                SleepTimerSheetContent(null, null, onAir.showEnd, now, {}, {})
            }
        }
    }
}
