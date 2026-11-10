package cz.slowdownradijo.app.analytics

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import cz.slowdownradijo.app.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant
import java.util.UUID
import kotlin.math.roundToInt

/** The screens, with the iOS names (`AnalyticsScreen`). */
enum class AnalyticsScreen(val id: String) {
    HOME("home"), MESSAGE("message"), STATS("stats"), MENU("menu"), SETTINGS("settings"), SHOW_REMINDERS("show_reminders"), NEWS("news"),
}

/** The events, with the iOS names and properties (`AnalyticsEvent` in Analytics.swift). */
sealed class AnalyticsEvent(val name: String, val properties: Map<String, Any>) {
    class AppOpened(kind: String) : AnalyticsEvent("app_opened", mapOf("kind" to kind))
    class ScreenViewed(screen: AnalyticsScreen) : AnalyticsEvent("screen_viewed", mapOf("screen" to screen.id))
    class LanguageChanged(to: String) : AnalyticsEvent("language_changed", mapOf("to" to to))
    class PlaybackStarted(trigger: String, showId: String?, connectMs: Int?, output: String) : AnalyticsEvent(
        "playback_started",
        buildMap<String, Any> {
            this["trigger"] = trigger; this["show_id"] = showId ?: "_"; this["output"] = output
            if (connectMs != null) this["connect_ms"] = connectMs
        },
    )
    class PlaybackStopped(seconds: Int, reason: String, showId: String?, reconnects: Int, output: String) : AnalyticsEvent(
        "playback_stopped",
        mapOf("seconds_listened" to rounded(seconds), "end_reason" to reason, "show_id" to (showId ?: "_"), "reconnects" to reconnects, "output" to output),
    )
    class PlaybackFailed(stage: String, showId: String?) : AnalyticsEvent("playback_failed", mapOf("stage" to stage, "show_id" to (showId ?: "_")))
    class SleepTimerSet(option: String) : AnalyticsEvent("sleep_timer_set", mapOf("option" to option))
    class OutputChanged(from: String, to: String, playing: Boolean) : AnalyticsEvent("output_changed", mapOf("from" to from, "to" to to, "playing" to playing))
    class ShowReminderChanged(showId: String, isOn: Boolean, source: String) : AnalyticsEvent("show_reminder_changed", mapOf("show_id" to showId, "on" to isOn, "source" to source))
    class ShowNotificationOpened(showId: String?, listen: Boolean) : AnalyticsEvent("show_notification_opened", mapOf("show_id" to (showId ?: "_"), "listen" to listen))
    class SpotifyOpened(showId: String?) : AnalyticsEvent("spotify_opened", mapOf("show_id" to (showId ?: "_")))
    class LinkOpened(target: String) : AnalyticsEvent("link_opened", mapOf("target" to target))
    class StatsOpened(communityUnlocked: Boolean) : AnalyticsEvent("stats_opened", mapOf("community_unlocked" to communityUnlocked))
    class MessageSent(success: Boolean, seconds: Int) : AnalyticsEvent("message_sent", mapOf("success" to success, "duration_s" to rounded(seconds, 5)))
    class FeedbackSent(success: Boolean) : AnalyticsEvent("feedback_sent", mapOf("success" to success))

    companion object {
        fun rounded(seconds: Int, step: Int = 10) = maxOf(0, (seconds.toDouble() / step).roundToInt() * step)
    }
}

/** Sends events to PostHog (EU), as the iOS app does with its SDK. */
interface AnalyticsSink {
    suspend fun send(distinctId: String, events: List<Pair<AnalyticsEvent, Instant>>, properties: Map<String, Any>)
}

/**
 * PostHog's capture API without the SDK: no device details, no person
 * profiles, nothing automatic: only the events the iOS app sends.
 */
class PostHogSink(private val client: OkHttpClient, private val host: String = "https://eu.i.posthog.com") : AnalyticsSink {
    override suspend fun send(distinctId: String, events: List<Pair<AnalyticsEvent, Instant>>, properties: Map<String, Any>) = withContext(Dispatchers.IO) {
        val body = buildJsonObject {
            put("api_key", PROJECT_TOKEN)
            put("batch", buildJsonArray {
                for ((event, at) in events) add(buildJsonObject {
                    put("event", event.name)
                    put("timestamp", at.toString())
                    put("properties", buildJsonObject {
                        put("distinct_id", distinctId)
                        put("\$process_person_profile", false)
                        for ((key, value) in properties + event.properties) put(key, json(value))
                    })
                })
            })
        }
        client.newCall(Request.Builder().url("$host/batch/").post(body.toString().toRequestBody("application/json".toMediaType())).build()).execute().use {
            if (!it.isSuccessful) throw java.io.IOException("posthog ${it.code}")
        }
    }

    private fun json(value: Any): JsonElement = when (value) {
        is Boolean -> JsonPrimitive(value)
        is Number -> JsonPrimitive(value)
        else -> JsonPrimitive(value.toString())
    }

    companion object {
        /** The same project as iOS (a write-only public token). */
        const val PROJECT_TOKEN = "phc_wQbQcZR2RkojLQUaCsokAx6wqnkr7sK5XqH37bKoaPUb"
    }
}

/**
 * Product analytics only after the listener agrees, as `Analytics.swift`:
 * asked from the third launch on the home screen, switchable in Settings;
 * saying no drops what is queued and forgets the anonymous id.
 */
class Analytics(
    context: Context,
    private val sink: AnalyticsSink,
    private val scope: CoroutineScope,
    private val language: () -> String,
    private val now: () -> Instant = Instant::now,
) {
    enum class Consent { UNKNOWN, GRANTED, DENIED }

    private val prefs = context.getSharedPreferences("analytics", Context.MODE_PRIVATE)
    private val _consent = MutableStateFlow(runCatching { Consent.valueOf(prefs.getString(CONSENT, "")!!.uppercase()) }.getOrDefault(Consent.UNKNOWN))
    val consent: StateFlow<Consent> = _consent.asStateFlow()
    private val queue = mutableListOf<Pair<AnalyticsEvent, Instant>>()
    private var flushJob: Job? = null
    private var backgroundedAt: Instant? = null

    val isEnabled get() = _consent.value == Consent.GRANTED
    val shouldAskForConsent get() = _consent.value == Consent.UNKNOWN && prefs.getInt(LAUNCHES, 0) >= ASK_FROM_LAUNCH

    private val distinctId: String
        get() = prefs.getString(ID, null) ?: UUID.randomUUID().toString().also { prefs.edit().putString(ID, it).apply() }

    /** Once per process: counts the launch and sends app_opened. */
    fun start() {
        prefs.edit().putInt(LAUNCHES, prefs.getInt(LAUNCHES, 0) + 1).apply()
        track(AnalyticsEvent.AppOpened("cold"))
    }

    fun onBackground() {
        backgroundedAt = now()
        flush()
    }

    /** Back after half an hour or more counts as a new opening. */
    fun onForeground() {
        val since = backgroundedAt ?: return
        backgroundedAt = null
        if (now().epochSecond - since.epochSecond >= REOPEN_AFTER) track(AnalyticsEvent.AppOpened("warm"))
    }

    fun setConsent(granted: Boolean) {
        _consent.value = if (granted) Consent.GRANTED else Consent.DENIED
        prefs.edit().putString(CONSENT, _consent.value.name.lowercase()).apply()
        if (granted) {
            track(AnalyticsEvent.AppOpened("consent"))
        } else {
            synchronized(queue) { queue.clear() }
            prefs.edit().remove(ID).apply()
        }
    }

    fun track(event: AnalyticsEvent) {
        if (!isEnabled) return
        val size = synchronized(queue) { queue += event to now(); queue.size }
        if (size >= FLUSH_AT) flush() else scheduleFlush()
    }

    fun screen(screen: AnalyticsScreen) = track(AnalyticsEvent.ScreenViewed(screen))

    private fun scheduleFlush() {
        if (flushJob?.isActive == true) return
        flushJob = scope.launch {
            delay(FLUSH_INTERVAL_MS)
            flushNow()
        }
    }

    fun flush() {
        scope.launch { flushNow() }
    }

    suspend fun flushNow() {
        if (!isEnabled) return
        val batch = synchronized(queue) { queue.toList().also { queue.clear() } }
        if (batch.isEmpty()) return
        val common = mapOf(
            "language" to language(),
            "schema_version" to SCHEMA_VERSION,
            "platform" to "android",
            "\$os" to "Android",
            "\$os_version" to Build.VERSION.RELEASE,
            "\$app_version" to BuildConfig.VERSION_NAME,
            "\$app_build" to BuildConfig.VERSION_CODE.toString(),
            "\$lib" to "slowdownradijo-android",
        )
        try {
            sink.send(distinctId, batch, common)
        } catch (_: Exception) {
            // Offline: back in the queue (bounded), sent with the next batch.
            synchronized(queue) { queue.addAll(0, batch.takeLast(MAX_QUEUE - queue.size.coerceAtMost(MAX_QUEUE))) }
        }
    }

    private companion object {
        const val CONSENT = "analytics.consent"
        const val LAUNCHES = "analytics.launchCount"
        const val ID = "analytics.distinctId"
        const val ASK_FROM_LAUNCH = 3
        const val REOPEN_AFTER = 30 * 60L
        const val SCHEMA_VERSION = 1
        const val FLUSH_AT = 20
        const val FLUSH_INTERVAL_MS = 30_000L
        const val MAX_QUEUE = 200
    }
}

/** Where the sound goes, with the iOS names (`AudioOutput.swift`). */
object AudioOutput {
    fun kind(context: Context): String {
        val manager = context.getSystemService(AudioManager::class.java) ?: return "phone"
        val types = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toSet()
        val bluetooth = buildSet {
            add(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP); add(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
            if (Build.VERSION.SDK_INT >= 31) { add(AudioDeviceInfo.TYPE_BLE_HEADSET); add(AudioDeviceInfo.TYPE_BLE_SPEAKER) }
        }
        val wired = setOf(AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_LINE_ANALOG)
        return when {
            types.any { it in bluetooth } -> "bluetooth"
            types.any { it in wired } -> "wired"
            AudioDeviceInfo.TYPE_HDMI in types -> "hdmi"
            else -> "phone"
        }
    }
}
