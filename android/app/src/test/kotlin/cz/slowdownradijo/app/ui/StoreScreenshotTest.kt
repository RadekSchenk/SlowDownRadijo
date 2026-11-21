package cz.slowdownradijo.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.chat.ChatContent
import cz.slowdownradijo.app.chat.ChatHomeSection
import cz.slowdownradijo.app.chat.ChatMessage
import cz.slowdownradijo.app.chat.ChatService
import cz.slowdownradijo.app.chat.ChatTimeline
import cz.slowdownradijo.app.chat.ChatWriter
import cz.slowdownradijo.app.profile.ProfileActions
import cz.slowdownradijo.app.profile.ProfileContent
import cz.slowdownradijo.app.profile.SlowrideStats
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasText
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
    /** Monday 16 Nov 2026, 7:40 in Prague: Morning Coffee with DJ Pufaz, as on iOS (`StoreDemo`). */
    private val now = Instant.parse("2026-11-16T06:40:00Z")
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
        for (show in excludedShows) {
            check(compose.onAllNodes(hasText(show, substring = true)).fetchSemanticsNodes().isEmpty()) { "$name: $show is on screen" }
        }
        compose.onRoot().captureRoboImage("../store/screenshots/${language.code}/$name.png")
    }

    /** Shows that must not appear in the store's screenshots (the station's call). */
    private val excludedShows = listOf("Majkl")

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
            HomeScreen(HomeUi(onAir, PlaybackState.Playing, null, now), HomeActions()) {
                // The chat section under the player, as on the home page.
                ChatHomeSection(
                    ChatService.State(messages = chatMessages(language == AppLanguage.EN), loaded = true, lastSeenId = 10),
                    onOpen = {}, onSeen = {}, modifier = Modifier.padding(top = Theme.Spacing.xl), now = now,
                )
            }
        }
    }

    // The chat during Morning Coffee (as `StoreDemo.messages` on iOS).
    private fun msg(id: Long, minutesAgo: Double, name: String, body: String, role: String = "listener") =
        ChatMessage(id, "u-$name", name, role, body, show.id, "Morning Coffee", now.minusSeconds((minutesAgo * 60).toLong()).toString())

    private fun chatMessages(en: Boolean) = listOf(
        msg(1, 38.0, "DJ Pufaz", if (en) "Good morning! What are you listening to over coffee? ☕" else "Dobré ráno! Co dnes posloucháte u kafe? ☕", "dj"),
        msg(2, 12.0, "kafe_s_mlekem", if (en) "Good morning from tram number 9 🚋" else "Dobré ráno z tramvaje číslo 9 🚋"),
        msg(3, 10.0, "vinylovy_tom", if (en) "That intro woke me up better than an espresso" else "Ten úvod mě probudil líp než espresso"),
        msg(4, 9.0, "DJ Pufaz", if (en) "Thanks! Something by Khruangbin is coming up, stay tuned 🙌" else "Díky! Za chvíli přijde něco od Khruangbin, vydržte 🙌", "dj"),
        msg(5, 7.0, "jana_z_letne", if (en) "Hello to the whole office in Smíchov ☀️" else "Pozdrav celé kanceláři na Smíchově ☀️"),
        msg(6, 5.0, "nela", "🔥"), msg(7, 4.8, "marty", "🔥"), msg(8, 4.7, "ondra_b", "🔥"), msg(9, 4.6, "kafe_s_mlekem", "🔥"),
        msg(10, 2.0, "groove_petr", if (en) "Could I ask for something by Erykah Badu? 🙏" else "Můžu poprosit o něco od Erykah Badu? 🙏"),
    )

    private fun chat(language: AppLanguage) = capture("2_chat", language) {
        val messages = chatMessages(language == AppLanguage.EN)
        val pinned = messages.first().copy(pinnedAtText = now.minusSeconds(38 * 60).toString())
        Box(Modifier.fillMaxSize().background(Theme.background)) {
            // The chat as a sheet over the home screen, as in the app.
            RootScreen(Tab.RADIO, {}, menuOpen = false, menu = {}) {
                HomeScreen(HomeUi(onAir, PlaybackState.Playing, null, now), HomeActions()) {}
            }
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)))
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
                ChatContent(
                    state = ChatService.State(messages = messages, pinned = pinned, loaded = true, lastSeenId = 10),
                    show = show,
                    writer = ChatWriter(signedIn = true, name = "vinylovy_tom", role = "listener", mutedUntil = null, blocked = false),
                    draft = "", onDraft = {}, onSend = { _, _ -> }, onRetry = {}, onClose = {}, onRules = {}, onSeen = {},
                    showLabel = { id, title, _ -> id?.let { ChatTimeline.ShowLabel("07:00", title ?: it) } },
                    modifier = Modifier.fillMaxHeight(0.96f).clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)),
                    now = now,
                )
            }
        }
    }

    private val me = AccountService.Me(
        userId = "u-vinylovy_tom", nickname = "vinylovy_tom", registeredAtText = "2026-09-14T10:00:00Z",
        chatMessagesCount = 48, voiceMessagesCount = 3,
    )

    private val shows = listOf(
        StatsSummary.ShowShare("morning-coffee-s-dj-pufaz", "Morning Coffee", "DJ Pufaz", null, "ShowArtMorningCoffee", 32 * 3600, 0.39),
        StatsSummary.ShowShare("beat-brunch-s-jaro-cossiga", "Beat Brunch", "Jaro Cossiga", null, "ShowArtBeatBrunch", 21 * 3600, 0.26),
        StatsSummary.ShowShare("diggin-time-s-dj-magic", "Diggin' Time", "DJ Magič", null, "ShowArtDigginTime", 14 * 3600, 0.17),
        StatsSummary.ShowShare("weekend-aftertaste-s-cube-positive", "Weekend Aftertaste", "cube positive", null, "ShowArtWeekendAftertaste", 9 * 3600, 0.11),
        StatsSummary.ShowShare("africa-incorporated-s-chuck-diesal", "Africa Incorporated", "Chuck Diesal", null, "ShowArtAfricaIncorporated", 6 * 3600, 0.07),
    )

    private fun profile(language: AppLanguage) = capture("3_profile", language) {
        RootScreen(Tab.PROFILE, {}, menuOpen = false, menu = {}) {
            tabPage {
                ProfileContent(
                    AccountService.State.SignedIn(AccountService.SignInMethod.APPLE, null, me), busy = false, ProfileActions(), now,
                    SlowrideStats(310_440, shows.take(3)),
                )
            }
        }
    }

    private val summary = StatsSummary(
        todaySeconds = 40 * 60, totalSeconds = 310_440, communitySeconds = 1_238_424 * 3600,
        rank = 12, rankedListeners = 1284, aheadSeconds = 310_440 + 88 * 60, behindSeconds = 310_440 - 5 * 3600 - 32 * 60, listeningDays = 41,
        bars = listOf(60, 95, 40, 120, 75, 150, 40).mapIndexed { i, m ->
            StatsSummary.DayBar(LocalDate.parse("2026-11-10").plusDays(i.toLong()).toString(), (i + 2) % 7 + 1, m * 60, m == 150)
        },
        weekSeconds = 580 * 60, weekStart = LocalDate.parse("2026-11-10"), weekEnd = LocalDate.parse("2026-11-16"),
        shows = shows, showsSeconds = 82 * 3600,
    )

    private fun stats(language: AppLanguage) = capture("4_stats", language) {
        RootScreen(Tab.STATS, {}, menuOpen = false, menu = {}) {
            tabPage { StatsContent(StatsUi(summary, enabled = true, measuring = true, communityUnlocked = true, loadFailed = false), {}, {}) }
        }
    }

    private fun programme(language: AppLanguage) = capture("5_programme", language) {
        RootScreen(Tab.RADIO, {}, menuOpen = false, menu = {}) {
            tabPage {
                // Saturday: the weekdays have Show podle Majkla, which stays out of the store.
                HomeProgramSection(store.days.value, show, now, followed = setOf("beat-brunch-s-jaro-cossiga", "diggin-time-s-dj-magic"), onBell = {}, initialWeekday = 7)
            }
        }
    }

    private val levels = listOf(0.35f, 0.7f, 0.55f, 0.9f, 0.6f, 0.8f, 0.45f, 0.95f, 0.65f, 0.5f, 0.85f, 0.4f, 0.75f, 0.6f, 0.7f, 0.5f, 0.8f, 0.45f)

    private fun message(language: AppLanguage) = capture("6_message", language) {
        RootScreen(Tab.MESSAGE, {}, menuOpen = false, menu = {}) {
            tabPage {
                MessageContent(
                    MessageUi(VoiceMessageState.Recorded(File("x.m4a"), 38.0), levels = levels, isPlaying = true, playbackProgress = 0.55),
                    MessageActions(),
                )
            }
        }
    }

    @Test fun homeCs() = home(AppLanguage.CS)
    @Test fun chatCs() = chat(AppLanguage.CS)
    @Test fun profileCs() = profile(AppLanguage.CS)
    @Test fun statsCs() = stats(AppLanguage.CS)
    @Test fun programmeCs() = programme(AppLanguage.CS)
    @Test fun messageCs() = message(AppLanguage.CS)

    @Test fun homeEn() = home(AppLanguage.EN)
    @Test fun chatEn() = chat(AppLanguage.EN)
    @Test fun profileEn() = profile(AppLanguage.EN)
    @Test fun statsEn() = stats(AppLanguage.EN)
    @Test fun programmeEn() = programme(AppLanguage.EN)
    @Test fun messageEn() = message(AppLanguage.EN)
}
