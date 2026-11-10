package cz.slowdownradijo.app

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.RemoteHistoryService
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.SharedImages
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.data.WebScheduleService
import cz.slowdownradijo.app.home.NowPlayingModel
import cz.slowdownradijo.app.l10n.LanguageStore
import cz.slowdownradijo.app.l10n.inLanguage
import cz.slowdownradijo.app.player.IcyMetadataPoller
import cz.slowdownradijo.app.player.PlaybackState
import cz.slowdownradijo.app.player.RadioEngine
import cz.slowdownradijo.app.analytics.Analytics
import cz.slowdownradijo.app.analytics.AnalyticsEvent
import cz.slowdownradijo.app.analytics.AudioOutput
import cz.slowdownradijo.app.analytics.PlaybackAnalytics
import cz.slowdownradijo.app.analytics.PostHogSink
import cz.slowdownradijo.app.news.NewsService
import cz.slowdownradijo.app.news.NewsStore
import cz.slowdownradijo.app.feedback.FeedbackForm
import cz.slowdownradijo.app.feedback.FeedbackService
import cz.slowdownradijo.app.player.StopReason
import cz.slowdownradijo.app.message.VoiceMessage
import cz.slowdownradijo.app.message.VoiceMessageUploader
import cz.slowdownradijo.app.stats.ListeningStatsStore
import cz.slowdownradijo.app.stats.ListeningTracker
import cz.slowdownradijo.app.stats.SupabaseStatsApi
import cz.slowdownradijo.app.reminders.ShowReminders
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import cz.slowdownradijo.app.widget.WidgetUpdates
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.io.File
import java.time.Duration
import java.time.Instant

/** The app's long-lived objects, shared by the UI and [cz.slowdownradijo.app.player.PlaybackService]. */
class SlowDownApp : Application() {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    val http: OkHttpClient by lazy {
        OkHttpClient.Builder().callTimeout(Duration.ofSeconds(20)).build()
    }

    val language by lazy { LanguageStore(this) }
    val settings by lazy { AppSettings(this) }
    val reminders by lazy { ShowReminders(this, schedule) }

    val schedule by lazy { ScheduleStore(ScheduleStore.bundled(this), File(cacheDir, "schedule-web.json")) }
    private val webSchedule by lazy { WebScheduleService(http) }
    private val remoteHistory by lazy { RemoteHistoryService(http) }

    val radio by lazy { RadioEngine(this, scope) }
    val icy by lazy { IcyMetadataPoller(http.newBuilder().callTimeout(Duration.ofSeconds(10)).build()) }

    val nowPlaying by lazy {
        NowPlayingModel(
            schedule = schedule,
            scope = scope,
            latestLogged = {
                remoteHistory.fetchPage(before = null, windowStart = Instant.now().minus(Duration.ofHours(3)), limit = 1)
                    .firstOrNull()?.let { NowPlayingTrack(it.artist, it.title) to it.playedAt }
            },
            publish = { title, subtitle, show -> radio.updateNowPlaying(title, subtitle, artworkUri(show)) },
            hostedByKicker = { inLanguage(language.language.value).getString(R.string.hostedByKicker) },
        )
    }

    private val statsApi by lazy { SupabaseStatsApi(http, getSharedPreferences("stats-session", MODE_PRIVATE)) }
    val tracker by lazy {
        ListeningTracker(
            api = statsApi,
            prefs = getSharedPreferences("stats", MODE_PRIVATE),
            scope = scope,
            isEnabled = { settings.statsEnabled.value },
            // Credit the show on air at each tick.
            showProvider = { schedule.currentShow()?.id },
            appVersion = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}) android",
        )
    }
    val stats by lazy {
        ListeningStatsStore(statsApi, tracker, schedule, getSharedPreferences("stats", MODE_PRIVATE), scope, isEnabled = { settings.statsEnabled.value })
    }

    val voiceMessage by lazy {
        VoiceMessage(this, scope, VoiceMessageUploader(http.newBuilder().callTimeout(Duration.ofSeconds(60)).build()),
            pauseRadio = { radio.pause(StopReason.VOICE_MESSAGE) },
            onSent = { success, seconds -> analytics.track(AnalyticsEvent.MessageSent(success, seconds)) })
    }

    val news by lazy { NewsStore(this, NewsService(http)) }
    val feedback by lazy { FeedbackForm(FeedbackService(http)) { analytics.track(AnalyticsEvent.FeedbackSent(it)) } }

    val analytics by lazy { Analytics(this, PostHogSink(http), scope, language = { language.language.value.code }) }
    private val playbackAnalytics by lazy {
        PlaybackAnalytics(radio, analytics, getSharedPreferences("analytics", MODE_PRIVATE),
            currentShowId = { schedule.currentShow()?.id }, output = { AudioOutput.kind(this) },
            onListened = { reviewPrompt.addListening(it) })
    }

    val reviewPrompt by lazy { cz.slowdownradijo.app.review.ReviewPrompt(this) }

    private var started = false

    /** The song and show polling, from when the UI first shows. */
    fun startNowPlaying() {
        if (started) return
        started = true
        analytics.start()
        playbackAnalytics.start(scope)
        scope.launch {
            while (true) {
                kotlinx.coroutines.delay(60_000)
                playbackAnalytics.save()
            }
        }
        scope.launch { language.language.drop(1).collect { analytics.track(AnalyticsEvent.LanguageChanged(it.code)) } }
        icy.start(scope)
        nowPlaying.start(icy.track) { schedule.refresh(webSchedule::fetch) }
        // The lock screen's "Moderuje" follows the app's language.
        scope.launch { language.language.drop(1).collect { nowPlaying.publishNowPlaying() } }
        // Listening stats: every way of playing goes through the engine's state.
        scope.launch { radio.state.collect { tracker.update(isPlaying = it == PlaybackState.Playing) } }
        scope.launch { stats.refreshAll() }
        // A new post on the web since the last launch.
        scope.launch { news.checkForNewPost(language.language.value, reminders.notificationsAllowed()) }
        // The widget follows the show on air and the verified song while the app runs.
        scope.launch {
            nowPlaying.onAir.map { it.show?.id to it.verifiedTrack }.distinctUntilChanged().drop(1).collect {
                runCatching { WidgetUpdates.updateIfPlaced(this@SlowDownApp) }
            }
        }
        // Reminders follow the week as the web has it.
        reminders.reschedule()
        scope.launch { schedule.days.drop(1).collect { reminders.reschedule() } }
    }

    /** The show's bundled photo, else its photo on the web. */
    fun artworkUri(show: Show?): Uri? {
        SharedImages.drawable(show?.artworkName)?.let { id ->
            return Uri.Builder().scheme(ContentResolver.SCHEME_ANDROID_RESOURCE)
                .authority(packageName)
                .appendPath(resources.getResourceTypeName(id))
                .appendPath(resources.getResourceEntryName(id))
                .build()
        }
        return show?.imageURL?.let(Uri::parse)
    }
}

val android.content.Context.app get() = applicationContext as SlowDownApp
