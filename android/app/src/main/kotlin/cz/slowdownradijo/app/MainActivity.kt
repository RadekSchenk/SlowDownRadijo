package cz.slowdownradijo.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import cz.slowdownradijo.app.data.spotifySearchUrl
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeProgramSection
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.SleepTimerOption
import cz.slowdownradijo.app.home.SleepTimerSheet
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.menu.HubScreen
import cz.slowdownradijo.app.menu.MenuPages
import cz.slowdownradijo.app.menu.SettingsActions
import cz.slowdownradijo.app.menu.SettingsScreen
import cz.slowdownradijo.app.menu.SettingsUi
import cz.slowdownradijo.app.menu.ShowRemindersScreen
import cz.slowdownradijo.app.player.PlayTrigger
import cz.slowdownradijo.app.player.PlaybackService
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.reminders.ShowReminders
import cz.slowdownradijo.app.reminders.rememberReminderToggle
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.systemReducesMotion
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import java.time.Instant

class MainActivity : ComponentActivity() {
    private var controller: ListenableFuture<MediaController>? = null
    private var selectTab: (Tab) -> Unit = {}

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        val app = app
        app.startNowPlaying()
        // A radio app makes sound as soon as it opens, unless the listener turned that off.
        if (savedInstanceState == null && app.settings.autoplay.value && !intent.isReminder()) {
            app.radio.play(PlayTrigger.AUTOPLAY)
        }
        handleReminder(intent)

        setContent {
            val language by app.language.language.collectAsStateWithLifecycle()
            var tab by rememberSaveable { mutableStateOf(Tab.RADIO) }
            var menuOpen by rememberSaveable { mutableStateOf(false) }
            selectTab = { tab = it; menuOpen = false }

            ProvideAppLanguage(language) {
                CompositionLocalProvider(LocalReduceMotion provides systemReducesMotion()) {
                    SlowDownTheme {
                        RootScreen(
                            selected = tab,
                            onSelect = { tab = it },
                            menuOpen = menuOpen,
                            menu = { Menu(onClose = { menuOpen = false }) },
                        ) { page ->
                            when (page) {
                                Tab.RADIO -> RadioPage(onOpenMenu = { menuOpen = true })
                                Tab.STATS -> Placeholder("Statistiky")
                                Tab.MESSAGE -> Placeholder("Vzkaz")
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleReminder(intent)
    }

    private fun Intent.isReminder() = hasExtra(ShowReminders.EXTRA_SHOW_ID)

    /** A tap on "Právě začíná": home, and the radio for "Poslouchat". */
    private fun handleReminder(intent: Intent) {
        if (!intent.isReminder()) return
        selectTab(Tab.RADIO)
        if (intent.getBooleanExtra(ShowReminders.EXTRA_LISTEN, false) && app.radio.state.value != PlaybackState.Playing) {
            app.radio.play(PlayTrigger.NOTIFICATION)
        }
        intent.removeExtra(ShowReminders.EXTRA_SHOW_ID)
    }

    /** Binds the playback service, so it is there to go foreground when the radio plays. */
    override fun onStart() {
        super.onStart()
        controller = MediaController.Builder(this, SessionToken(this, ComponentName(this, PlaybackService::class.java))).buildAsync()
        app.reminders.reschedule()
    }

    override fun onStop() {
        controller?.let(MediaController::releaseFuture)
        controller = null
        super.onStop()
    }
}

@Composable
private fun RadioPage(onOpenMenu: () -> Unit) {
    val app = androidx.compose.ui.platform.LocalContext.current.app
    val onAir by app.nowPlaying.onAir.collectAsStateWithLifecycle()
    val playback by app.radio.state.collectAsStateWithLifecycle()
    val sleepFireAt by app.radio.sleepTimerFireAt.collectAsStateWithLifecycle()
    val days by app.schedule.days.collectAsStateWithLifecycle()
    val followed by app.reminders.followed.collectAsStateWithLifecycle()
    val now by produceState(Instant.now()) {
        while (true) {
            delay(1000 - System.currentTimeMillis() % 1000)
            value = Instant.now()
        }
    }
    var showingSleepTimer by rememberSaveable { mutableStateOf(false) }
    var sleepOption by remember { mutableStateOf<SleepTimerOption?>(null) }
    if (sleepFireAt == null) sleepOption = null
    val toggleReminder = rememberReminderToggle()
    val context = androidx.compose.ui.platform.LocalContext.current

    HomeScreen(
        HomeUi(onAir, playback, sleepFireAt, now),
        HomeActions(
            togglePlay = { app.radio.togglePlayPause() },
            openSleepTimer = { showingSleepTimer = true },
            openSong = { track ->
                spotifySearchUrl(track.artist, track.title)?.let {
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) }
                }
            },
            openMenu = onOpenMenu,
        ),
    ) {
        HomeProgramSection(
            days = days, currentShow = onAir.show, now = now, followed = followed,
            onBell = { show -> toggleReminder(show, show.id !in followed) },
            modifier = Modifier.padding(top = Theme.Spacing.xl),
        )
    }
    if (showingSleepTimer) {
        SleepTimerSheet(
            activeOption = sleepOption,
            fireAt = sleepFireAt,
            showEnd = onAir.showEnd,
            now = now,
            onSelect = { option ->
                val duration = option.duration
                val end = onAir.showEnd
                when {
                    duration != null -> app.radio.scheduleSleepTimer(duration)
                    end != null -> app.radio.scheduleSleepTimer(end)
                }
                sleepOption = option
                showingSleepTimer = false
            },
            onCancel = {
                app.radio.cancelSleepTimer()
                showingSleepTimer = false
            },
            onDismiss = { showingSleepTimer = false },
        )
    }
}

@Composable
private fun Menu(onClose: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val app = context.app
    HubScreen(
        onLanguage = { app.language.set(it) },
        onClose = onClose,
        pages = MenuPages(
            settings = { open, back ->
                val autoplay by app.settings.autoplay.collectAsStateWithLifecycle()
                val stats by app.settings.statsEnabled.collectAsStateWithLifecycle()
                val followed by app.reminders.followed.collectAsStateWithLifecycle()
                SettingsScreen(
                    SettingsUi(autoplay, followed.size, stats, analyticsEnabled = false),
                    SettingsActions(setAutoplay = app.settings::setAutoplay, setStats = app.settings::setStatsEnabled),
                    open, back,
                )
            },
            showReminders = { back ->
                val followed by app.reminders.followed.collectAsStateWithLifecycle()
                val toggle = rememberReminderToggle()
                ShowRemindersScreen(
                    shows = app.reminders.allShows, followed = followed,
                    notificationsBlocked = followed.isNotEmpty() && !app.reminders.notificationsAllowed(),
                    onToggle = toggle, onUnfollowAll = app.reminders::unfollowAll, back = back,
                )
            },
            news = { _, back -> Placeholder("Novinky", back) },
            newsDetail = { _, back -> Placeholder("Novinka", back) },
            feedback = { back -> Placeholder("Zpětná vazba", back) },
        ),
    )
}

/** Stands in for a page still being ported. */
@Composable
private fun Placeholder(title: String, back: (() -> Unit)? = null) {
    Box(Modifier.fillMaxSize().padding(20.dp), contentAlignment = Alignment.Center) {
        Text(title, style = Theme.Typography.Heading.page, color = Theme.textPrimary)
    }
}
