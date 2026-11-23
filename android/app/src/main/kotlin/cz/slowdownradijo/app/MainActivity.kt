package cz.slowdownradijo.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.github.jan.supabase.auth.handleDeeplinks
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
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import cz.slowdownradijo.app.home.AppHeader
import cz.slowdownradijo.app.home.AnalyticsConsentCard
import cz.slowdownradijo.app.analytics.AnalyticsEvent
import cz.slowdownradijo.app.analytics.AnalyticsScreen
import cz.slowdownradijo.app.news.NewsDetailScreen
import cz.slowdownradijo.app.news.NewsListScreen
import cz.slowdownradijo.app.feedback.DeviceInfo
import cz.slowdownradijo.app.feedback.FeedbackScreen
import cz.slowdownradijo.app.message.MessageActions
import cz.slowdownradijo.app.message.MessageAlert
import cz.slowdownradijo.app.message.MessageContent
import cz.slowdownradijo.app.message.MessageUi
import cz.slowdownradijo.app.stats.StatsContent
import cz.slowdownradijo.app.stats.StatsHomeBlock
import cz.slowdownradijo.app.stats.StatsUi
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
        handleAuthReturn(intent)

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
                            onSelect = {
                                if (it != tab) {
                                    app.analytics.screen(when (it) { Tab.RADIO -> AnalyticsScreen.HOME; Tab.STATS -> AnalyticsScreen.STATS; Tab.MESSAGE -> AnalyticsScreen.MESSAGE; Tab.PROFILE -> AnalyticsScreen.PROFILE })
                                    if (it == Tab.STATS) app.analytics.track(AnalyticsEvent.StatsOpened(app.stats.communityUnlocked))
                                }
                                tab = it
                                if (it == Tab.STATS) app.scope.launch { app.stats.refreshAll() }
                            },
                            menuOpen = menuOpen,
                            menu = { Menu(onClose = { menuOpen = false }) },
                        ) { page ->
                            when (page) {
                                Tab.RADIO -> RadioPage(onOpenMenu = { menuOpen = true; app.analytics.screen(AnalyticsScreen.MENU) }, onOpenStats = { tab = Tab.STATS })
                                Tab.STATS -> StatsPage(onOpenMenu = { menuOpen = true; app.analytics.screen(AnalyticsScreen.MENU) })
                                Tab.MESSAGE -> MessagePage(onOpenMenu = { menuOpen = true; app.analytics.screen(AnalyticsScreen.MENU) }, onBackToRadio = { tab = Tab.RADIO })
                                Tab.PROFILE -> cz.slowdownradijo.app.profile.ProfilePage(onOpenMenu = { menuOpen = true; app.analytics.screen(AnalyticsScreen.MENU) }, onOpenStats = { tab = Tab.STATS })
                            }
                        }
                        cz.slowdownradijo.app.chat.HostInviteSheet(onOpenChat = {
                            selectTab(Tab.RADIO)
                            app.chat.requestOpen()
                        })
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleReminder(intent)
        handleAuthReturn(intent)
    }

    /** Apple's web sign-in and the e-mail link come back to slowdownradijo://auth. */
    private fun handleAuthReturn(intent: Intent) {
        // A DJ invite (https://slowdownradijo.cz/dj/<code>, slowdownradijo://dj/<code>).
        if (app.chat.handleInvite(intent.dataString)) {
            intent.data = null
            return
        }
        if (intent.data?.scheme != "slowdownradijo") return
        app.supabase.handleDeeplinks(intent, onError = app.account::handleDeeplinkError)
    }

    private fun Intent.isReminder() = hasExtra(ShowReminders.EXTRA_SHOW_ID)

    /** A tap on "Právě začíná": home, and the radio for "Poslouchat". */
    private fun handleReminder(intent: Intent) {
        if (!intent.isReminder()) return
        selectTab(Tab.RADIO)
        app.analytics.track(AnalyticsEvent.ShowNotificationOpened(intent.getStringExtra(ShowReminders.EXTRA_SHOW_ID), intent.getBooleanExtra(ShowReminders.EXTRA_LISTEN, false)))
        if (intent.getBooleanExtra(ShowReminders.EXTRA_LISTEN, false) && app.radio.state.value != PlaybackState.Playing) {
            app.radio.play(PlayTrigger.NOTIFICATION)
        }
        intent.removeExtra(ShowReminders.EXTRA_SHOW_ID)
    }

    /** Binds the playback service, so it is there to go foreground when the radio plays. */
    override fun onStart() {
        super.onStart()
        app.analytics.onForeground()
        controller = MediaController.Builder(this, SessionToken(this, ComponentName(this, PlaybackService::class.java))).buildAsync()
        app.reminders.reschedule()
        app.chat.resume()
    }

    override fun onStop() {
        app.chat.pause()
        app.tracker.onBackground()
        app.analytics.onBackground()
        controller?.let(MediaController::releaseFuture)
        controller = null
        super.onStop()
    }
}

@Composable
private fun statsUi(): StatsUi {
    val app = androidx.compose.ui.platform.LocalContext.current.app
    val version by app.stats.version.collectAsStateWithLifecycle()
    val enabled by app.settings.statsEnabled.collectAsStateWithLifecycle()
    val measuring by app.tracker.measuring.collectAsStateWithLifecycle()
    val failed by app.stats.loadFailed.collectAsStateWithLifecycle()
    // `version` changes whenever a second is counted or a refresh lands.
    val summary = remember(version, enabled) { app.stats.summary() }
    return StatsUi(summary, enabled, measuring, app.stats.communityUnlocked, failed)
}

@Composable
private fun StatsPage(onOpenMenu: () -> Unit) {
    val app = androidx.compose.ui.platform.LocalContext.current.app
    val onAir by app.nowPlaying.onAir.collectAsStateWithLifecycle()
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    androidx.compose.foundation.layout.Column(
        Modifier
            .fillMaxSize()
            .androidx_verticalScroll()
            .padding(horizontal = 20.dp)
    ) {
        androidx.compose.foundation.layout.Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
        AppHeader(hostedShowOnAir = onAir.show?.hostName != null, onMenu = onOpenMenu)
        androidx.compose.foundation.layout.Box(Modifier.padding(top = Theme.Spacing.md, bottom = 36.dp)) {
            StatsContent(
                statsUi(),
                onEnable = {
                    app.settings.setStatsEnabled(true)
                    app.tracker.enabledPreferenceChanged()
                    scope.launch { app.stats.refreshAll(force = true) }
                },
                onRetry = { scope.launch { app.stats.refreshAll(force = true) } },
            )
        }
    }
}

@Composable
private fun Modifier.androidx_verticalScroll() = verticalScroll(rememberScrollState())

@Composable
private fun MessagePage(onOpenMenu: () -> Unit, onBackToRadio: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val app = context.app
    val message = app.voiceMessage
    val onAir by app.nowPlaying.onAir.collectAsStateWithLifecycle()
    val state by message.state.collectAsStateWithLifecycle()
    val elapsed by message.elapsed.collectAsStateWithLifecycle()
    val levels by message.levels.collectAsStateWithLifecycle()
    val playing by message.isPlaying.collectAsStateWithLifecycle()
    val progress by message.playbackProgress.collectAsStateWithLifecycle()
    val uploadFailed by message.uploadFailed.collectAsStateWithLifecycle()
    var micDenied by remember { mutableStateOf(false) }
    var startAfterGrant by remember { mutableStateOf<(() -> Unit)?>(null) }
    val permission = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) startAfterGrant?.invoke() else micDenied = true
        startAfterGrant = null
    }
    fun withMic(action: () -> Unit) {
        if (androidx.core.content.ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            action()
        } else {
            startAfterGrant = action
            permission.launch(android.Manifest.permission.RECORD_AUDIO)
        }
    }

    androidx.compose.foundation.layout.Column(
        Modifier
            .fillMaxSize()
            .androidx_verticalScroll()
            .padding(horizontal = 20.dp)
            .padding(bottom = Theme.Spacing.xl)
    ) {
        androidx.compose.foundation.layout.Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
        AppHeader(hostedShowOnAir = onAir.show?.hostName != null, onMenu = onOpenMenu)
        MessageContent(
            MessageUi(state, elapsed, levels, playing, progress),
            MessageActions(
                start = { withMic(message::startRecording) },
                stop = message::stopRecording,
                cancel = message::cancelRecording,
                togglePlayback = message::togglePlayback,
                submit = message::submit,
                retry = { withMic(message::retry) },
                discard = message::discardRecording,
                recordAnother = message::recordAnother,
                backToRadio = onBackToRadio,
            ),
        )
    }
    if (micDenied) {
        MessageAlert(
            androidx.compose.ui.res.stringResource(R.string.micUnavailableTitle),
            androidx.compose.ui.res.stringResource(R.string.micUnavailableMessage),
        ) { micDenied = false }
    }
    if (uploadFailed) {
        MessageAlert(
            androidx.compose.ui.res.stringResource(R.string.uploadFailedTitle),
            androidx.compose.ui.res.stringResource(R.string.uploadFailedMessage),
            message::dismissUploadFailed,
        )
    }
}

@Composable
private fun RadioPage(onOpenMenu: () -> Unit, onOpenStats: () -> Unit) {
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

    val output by app.audioOutput.output.collectAsStateWithLifecycle()
    // A switch between outputs already connected adds or removes no device: look again now and then.
    androidx.compose.runtime.LaunchedEffect(Unit) {
        while (true) {
            app.audioOutput.refresh()
            delay(2_000)
        }
    }
    val earlierSongs by produceState(emptyList<cz.slowdownradijo.app.data.RecentSong>(), onAir.verifiedTrack, onAir.showStart) {
        value = emptyList()
        val track = onAir.verifiedTrack ?: return@produceState
        value = app.earlierSongs(track, onAir.showStart)
    }
    val winterLook by app.settings.winterLook.collectAsStateWithLifecycle()
    val alarmSettings by app.radioAlarm.settings.collectAsStateWithLifecycle()
    val alarmWokeAt by app.radioAlarm.wokeAt.collectAsStateWithLifecycle()
    val alarmSnoozedUntil by app.radioAlarm.snoozedUntil.collectAsStateWithLifecycle()
    var showingAlarm by rememberSaveable { mutableStateOf(false) }
    HomeScreen(
        HomeUi(onAir, playback, sleepFireAt, now, output, earlierSongs, winter = winterLook && cz.slowdownradijo.app.winter.WinterSeason.isSeason(now), alarm = alarmSettings),
        HomeActions(
            togglePlay = { app.radio.togglePlayPause() },
            openSleepTimer = { showingSleepTimer = true },
            openAlarm = { showingAlarm = true },
            openSong = { track ->
                app.analytics.track(AnalyticsEvent.SpotifyOpened(onAir.show?.id))
                spotifySearchUrl(track.artist, track.title)?.let {
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) }
                }
            },
            openMenu = onOpenMenu,
            openOutputPicker = {
                app.analytics.track(AnalyticsEvent.OutputPickerOpened(output.kind))
                cz.slowdownradijo.app.player.AudioOutputs.openSwitcher(context)
            },
        ),
    ) {
        // Figma "Budík s rádiem" B5/B6: the morning card after the alarm, or the snooze.
        cz.slowdownradijo.app.alarm.RadioAlarmCard(
            wokeAt = alarmWokeAt, snoozedUntil = alarmSnoozedUntil, settings = alarmSettings,
            canSnooze = app.radioAlarm.canSnooze, now = now,
            onSnooze = app.radioAlarm::snooze, onDone = app.radioAlarm::done,
            onCancelSnooze = app.radioAlarm::cancelSnooze,
            onPlayNow = { app.radioAlarm.cancelSnooze(); app.radioAlarm.fire() },
            modifier = Modifier.padding(top = Theme.Spacing.xl),
        )
        // Figma "Soutěže" H1–H2: the contest card between the player and the chat.
        val contest by app.contests.current.collectAsStateWithLifecycle()
        val dismissedContests by app.contests.dismissed.collectAsStateWithLifecycle()
        val accountState by app.account.state.collectAsStateWithLifecycle()
        var openContest by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<cz.slowdownradijo.app.contests.ContestService.Contest?>(null) }
        var dismissingContest by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<cz.slowdownradijo.app.contests.ContestService.Contest?>(null) }
        androidx.compose.runtime.LaunchedEffect(accountState) { app.contests.refresh() }
        val contestScope = androidx.compose.runtime.rememberCoroutineScope()
        androidx.lifecycle.compose.LifecycleResumeEffect(Unit) {
            val job = contestScope.launch { app.contests.refresh() }
            onPauseOrDispose { job.cancel() }
        }
        val infobox = app.contests.infoboxContest(contest, dismissedContests, now)
        androidx.compose.animation.AnimatedVisibility(
            visible = infobox != null,
            enter = androidx.compose.animation.fadeIn() + androidx.compose.animation.expandVertically(),
            exit = androidx.compose.animation.fadeOut() + androidx.compose.animation.shrinkVertically(),
        ) {
            val shown = infobox ?: return@AnimatedVisibility
            androidx.compose.runtime.LaunchedEffect(shown.id) { app.contests.infoboxShown(shown) }
            cz.slowdownradijo.app.contests.ContestInfobox(
                shown,
                onOpen = {
                    app.analytics.track(AnalyticsEvent.ContestInfoboxTapped(shown.id))
                    openContest = shown
                },
                onClose = { dismissingContest = shown },
                modifier = Modifier.padding(top = Theme.Spacing.xl),
            )
        }
        openContest?.let { cz.slowdownradijo.app.contests.ContestSheet(it) { openContest = null } }
        dismissingContest?.let { shown ->
            cz.slowdownradijo.app.profile.ConfirmDialog(
                androidx.compose.ui.res.stringResource(R.string.contestDismissTitle),
                androidx.compose.ui.res.stringResource(R.string.contestDismissBody, shown.title),
                androidx.compose.ui.res.stringResource(R.string.contestDismissConfirm),
                destructive = true,
                cancel = androidx.compose.ui.res.stringResource(R.string.contestKeep),
                onDismiss = { dismissingContest = null },
            ) {
                dismissingContest = null
                app.contests.dismiss(shown)
            }
        }
        val chatState by app.chat.state.collectAsStateWithLifecycle()
        var chatOpening by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<Boolean?>(null) }
        // "Otevřít chat" after linking a DJ account.
        val openRequests by app.chat.openRequests.collectAsStateWithLifecycle()
        var handledOpen by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableIntStateOf(openRequests) }
        androidx.compose.runtime.LaunchedEffect(openRequests) {
            if (openRequests != handledOpen) {
                handledOpen = openRequests
                app.analytics.track(cz.slowdownradijo.app.analytics.AnalyticsEvent.ChatOpened("invite", app.account.analyticsAccount))
                chatOpening = false
            }
        }
        cz.slowdownradijo.app.chat.ChatHomeSection(
            chatState,
            onOpen = {
                app.analytics.track(cz.slowdownradijo.app.analytics.AnalyticsEvent.ChatOpened(if (it) "home_field" else "home_section", app.account.analyticsAccount))
                chatOpening = it
            },
            onSeen = app.chat::markSeen,
            modifier = Modifier.padding(top = Theme.Spacing.xl),
            now = now,
        )
        chatOpening?.let { withKeyboard ->
            cz.slowdownradijo.app.chat.ChatSheet(withKeyboard, onAir.show) { chatOpening = null }
        }
        val stats = statsUi()
        if (stats.enabled) StatsHomeBlock(stats, onOpenStats, Modifier.padding(top = Theme.Spacing.xl))
        val consent by app.analytics.consent.collectAsStateWithLifecycle()
        val askingConsent = consent == cz.slowdownradijo.app.analytics.Analytics.Consent.UNKNOWN && app.analytics.shouldAskForConsent
        // A returning listener: Google Play's own rating dialog, once the
        // home screen has been up a moment and not over the analytics question.
        val shouldAskReview by app.reviewPrompt.shouldAsk.collectAsStateWithLifecycle()
        val activity = androidx.activity.compose.LocalActivity.current
        androidx.compose.runtime.LaunchedEffect(shouldAskReview && !askingConsent) {
            if (!shouldAskReview || askingConsent || activity == null) return@LaunchedEffect
            delay(4_000)
            app.reviewPrompt.ask(activity)
        }
        androidx.compose.animation.AnimatedVisibility(askingConsent) {
            AnalyticsConsentCard(app.analytics::setConsent, Modifier.padding(top = Theme.Spacing.xl))
        }
        HomeProgramSection(
            days = days, currentShow = onAir.show, now = now, followed = followed,
            onBell = { show ->
                val on = show.id !in followed
                toggleReminder(show, on)
                app.analytics.track(AnalyticsEvent.ShowReminderChanged(show.id, on, "bell"))
            },
            modifier = Modifier.padding(top = Theme.Spacing.xl),
        )
    }
    if (showingAlarm) {
        val context = androidx.compose.ui.platform.LocalContext.current
        // Back from the system's "Alarms & reminders" screen: look again.
        var canExact by remember { mutableStateOf(app.radioAlarm.canScheduleExact()) }
        androidx.lifecycle.compose.LifecycleResumeEffect(Unit) {
            canExact = app.radioAlarm.canScheduleExact()
            app.radioAlarm.reschedule()
            onPauseOrDispose { }
        }
        val fire = app.radioAlarm.nextFire(settings = alarmSettings.copy(isOn = true))
        cz.slowdownradijo.app.alarm.RadioAlarmSheet(
            cz.slowdownradijo.app.alarm.RadioAlarmSheetUi(alarmSettings, canExact, fire, fire?.let { app.schedule.currentShow(it) }),
            cz.slowdownradijo.app.alarm.RadioAlarmActions(
                update = app.radioAlarm::update,
                openPermission = { runCatching { context.startActivity(app.radioAlarm.exactAlarmSettingsIntent()) } },
                test = app.radioAlarm::test,
            ),
            onDismiss = { showingAlarm = false },
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
                app.analytics.track(AnalyticsEvent.SleepTimerSet(option.analyticsName))
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
        onLinkOpened = { app.analytics.track(AnalyticsEvent.LinkOpened(it)) },
        pages = MenuPages(
            settings = { open, back ->
                androidx.compose.runtime.LaunchedEffect(Unit) { app.analytics.screen(AnalyticsScreen.SETTINGS) }
                val analyticsConsent by app.analytics.consent.collectAsStateWithLifecycle()
                val autoplay by app.settings.autoplay.collectAsStateWithLifecycle()
                val stats by app.settings.statsEnabled.collectAsStateWithLifecycle()
                val streamQuality by app.settings.streamQuality.collectAsStateWithLifecycle()
                val winterLook by app.settings.winterLook.collectAsStateWithLifecycle()
                val followed by app.reminders.followed.collectAsStateWithLifecycle()
                SettingsScreen(
                    SettingsUi(autoplay, followed.size, stats, analyticsEnabled = analyticsConsent == cz.slowdownradijo.app.analytics.Analytics.Consent.GRANTED, streamQuality = streamQuality, winterLook = winterLook.takeIf { cz.slowdownradijo.app.winter.WinterSeason.isSeason(Instant.now()) }),
                    SettingsActions(
                        setAutoplay = app.settings::setAutoplay,
                        setStats = {
                            app.settings.setStatsEnabled(it)
                            app.tracker.enabledPreferenceChanged()
                        },
                        setAnalytics = app.analytics::setConsent,
                        setStreamQuality = {
                            app.settings.setStreamQuality(it)
                            app.radio.streamQualityChanged()
                        },
                        setWinterLook = app.settings::setWinterLook,
                        deleteStats = { runCatching { app.tracker.deleteAllData() }.isSuccess },
                    ),
                    open, back,
                )
            },
            showReminders = { back ->
                androidx.compose.runtime.LaunchedEffect(Unit) { app.analytics.screen(AnalyticsScreen.SHOW_REMINDERS) }
                val followed by app.reminders.followed.collectAsStateWithLifecycle()
                val reminderToggle = rememberReminderToggle()
                val toggle: (cz.slowdownradijo.app.data.Show, Boolean) -> Unit = { show, on ->
                    reminderToggle(show, on)
                    app.analytics.track(AnalyticsEvent.ShowReminderChanged(show.id, on, "settings"))
                }
                ShowRemindersScreen(
                    shows = app.reminders.allShows, followed = followed,
                    notificationsBlocked = followed.isNotEmpty() && !app.reminders.notificationsAllowed(),
                    onToggle = toggle, onUnfollowAll = app.reminders::unfollowAll, back = back,
                )
            },
            news = { open, back ->
                androidx.compose.runtime.LaunchedEffect(Unit) { app.analytics.screen(AnalyticsScreen.NEWS) }
                val state by app.news.state.collectAsStateWithLifecycle()
                val on by app.news.notificationsEnabled.collectAsStateWithLifecycle()
                androidx.compose.runtime.LaunchedEffect(Unit) { app.news.loadIfNeeded() }
                val permission = androidx.activity.compose.rememberLauncherForActivityResult(
                    androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
                ) {}
                NewsListScreen(
                    state, on,
                    onNotifications = {
                        app.news.setNotificationsEnabled(it)
                        if (it && android.os.Build.VERSION.SDK_INT >= 33 && !app.reminders.notificationsAllowed()) {
                            permission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                        }
                    },
                    onOpen = { open(cz.slowdownradijo.app.menu.MenuPage.NewsDetail(it.id)) },
                    back = back,
                )
            },
            newsDetail = { id, back -> NewsDetailScreen(app.news.post(id), back) },
            feedback = { back ->
                val message by app.feedback.message.collectAsStateWithLifecycle()
                val state by app.feedback.state.collectAsStateWithLifecycle()
                val language = cz.slowdownradijo.app.l10n.LocalAppLanguage.current
                val scope = androidx.compose.runtime.rememberCoroutineScope()
                FeedbackScreen(
                    message, state, app.feedback::edit,
                    onSubmit = { scope.launch { app.feedback.submit(DeviceInfo.current(language.code)) } },
                    onReset = app.feedback::reset, back = back,
                )
            },
        ),
    )
}

