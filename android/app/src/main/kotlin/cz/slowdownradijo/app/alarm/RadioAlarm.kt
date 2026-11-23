package cz.slowdownradijo.app.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.MoreExecutors
import cz.slowdownradijo.app.MainActivity
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.l10n.inLanguage
import cz.slowdownradijo.app.player.PlayTrigger
import cz.slowdownradijo.app.player.PlaybackService
import cz.slowdownradijo.app.player.PlaybackState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/** The alarm's settings, as `RadioAlarmSettings` on iOS. Weekdays are ISO (1 = Monday … 7 = Sunday); none = once. */
@Serializable
data class RadioAlarmSettings(
    val isOn: Boolean = false,
    val hour: Int = 6,
    val minute: Int = 30,
    val weekdays: Set<Int> = setOf(1, 2, 3, 4, 5),
    val snoozeMinutes: Int = 9,
) {
    companion object {
        val SNOOZE_CHOICES = listOf(5, 9, 10, 15)
    }
}

/**
 * "Budík s rádiem" (Figma "Budík s rádiem", docs/radio-alarm.md): at the set time the live stream
 * starts by itself — an exact alarm ([AlarmManager.setAlarmClock], the alarm icon in the status bar)
 * starts the player through its media session — with a notification to snooze or turn it off. The
 * volume rises over 30 s. If the stream isn't playing within 20 s (no internet), the phone's alarm
 * sound rings instead, until dismissed. iOS rings a system alarm and needs a tap to start the radio.
 */
class RadioAlarm(private val context: Context, private val scope: CoroutineScope, private val zone: () -> ZoneId = ZoneId::systemDefault) {
    private val prefs = context.getSharedPreferences("radioAlarm", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    private val _settings = MutableStateFlow(prefs.getString(SETTINGS, null)?.let { runCatching { json.decodeFromString<RadioAlarmSettings>(it) }.getOrNull() } ?: RadioAlarmSettings())
    val settings: StateFlow<RadioAlarmSettings> = _settings.asStateFlow()

    /** The radio was started by the alarm at this moment (the "Dobré ráno" card for 15 minutes). */
    private val _wokeAt = MutableStateFlow<Instant?>(null)
    val wokeAt: StateFlow<Instant?> = _wokeAt.asStateFlow()

    /** Snoozed: the radio plays again at this moment. */
    private val _snoozedUntil = MutableStateFlow<Instant?>(null)
    val snoozedUntil: StateFlow<Instant?> = _snoozedUntil.asStateFlow()

    private var snoozeCount = 0
    val canSnooze: Boolean get() = snoozeCount < MAX_SNOOZES

    private var controller: com.google.common.util.concurrent.ListenableFuture<MediaController>? = null
    private var watchdog: Job? = null
    private var ramp: Job? = null

    /** Exact alarms allowed (Android 12+ asks in Settings → "Alarms & reminders"). */
    fun canScheduleExact(): Boolean =
        Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true

    /** The system screen where the listener allows exact alarms. */
    fun exactAlarmSettingsIntent(): Intent =
        if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, android.net.Uri.parse("package:${context.packageName}"))
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${context.packageName}"))

    fun update(change: (RadioAlarmSettings) -> RadioAlarmSettings) {
        val next = change(_settings.value)
        _settings.value = next
        prefs.edit().putString(SETTINGS, json.encodeToString(RadioAlarmSettings.serializer(), next)).apply()
        reschedule()
    }

    /** The next time it rings, from [after]. */
    fun nextFire(after: Instant = Instant.now(), settings: RadioAlarmSettings = _settings.value): Instant? {
        if (!settings.isOn) return null
        return nextFire(after, settings, zone())
    }

    /** Plans the next ring (or none), e.g. after a change, a reboot or an update. */
    fun reschedule(now: Instant = Instant.now()) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = fireIntent(ACTION_FIRE, 0)
        alarms.cancel(intent)
        val at = nextFire(now) ?: return
        if (!canScheduleExact()) return
        alarms.setAlarmClock(AlarmManager.AlarmClockInfo(at.toEpochMilli(), openApp(1)), intent)
    }

    // MARK: Ringing

    /** The alarm (or the end of a snooze): starts the radio through its media session. */
    fun fire() {
        _wokeAt.value = Instant.now()
        _snoozedUntil.value = null
        if (_settings.value.weekdays.isEmpty()) {
            update { it.copy(isOn = false) }
        } else {
            reschedule(Instant.now().plusSeconds(60))
        }
        startRadio()
        notifyRinging(fallback = false)
        watchdog?.cancel()
        watchdog = scope.launch {
            delay(FALLBACK_AFTER_MS)
            if (context.app.radio.state.value != PlaybackState.Playing) notifyRinging(fallback = true)
        }
    }

    private fun startRadio() {
        val radio = context.app.radio
        radio.nextSessionTrigger = PlayTrigger.ALARM
        controller?.let(MediaController::releaseFuture)
        val future = MediaController.Builder(context, SessionToken(context, ComponentName(context, PlaybackService::class.java))).buildAsync()
        controller = future
        future.addListener({
            runCatching { future.get().play() }
            rampVolume()
        }, MoreExecutors.directExecutor())
    }

    /** From 20 % to full over 30 s: no blast of sound at 6:30. */
    private fun rampVolume() {
        ramp?.cancel()
        ramp = scope.launch {
            val player = context.app.radio.player
            for (step in 0..30) {
                player.volume = 0.2f + 0.8f * step / 30f
                delay(1_000)
            }
            player.volume = 1f
        }
    }

    /** "Odložit": the radio pauses, plays again after the snooze time. */
    fun snooze() {
        snoozeCount++
        watchdog?.cancel()
        stopFallback()
        context.app.radio.pause()
        val until = Instant.now().plusSeconds(_settings.value.snoozeMinutes * 60L)
        _snoozedUntil.value = until
        _wokeAt.value = null
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = fireIntent(ACTION_SNOOZE_END, 2)
        if (canScheduleExact()) alarms.setAlarmClock(AlarmManager.AlarmClockInfo(until.toEpochMilli(), openApp(3)), intent)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, until.toEpochMilli(), intent)
        notifySnoozed(until)
    }

    fun cancelSnooze() {
        _snoozedUntil.value = null
        snoozeCount = 0
        context.getSystemService(AlarmManager::class.java)?.cancel(fireIntent(ACTION_SNOOZE_END, 2))
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }

    /** "Hotovo" / "Hrát dál": the card and notification go, the radio keeps playing. */
    fun done() {
        _wokeAt.value = null
        snoozeCount = 0
        watchdog?.cancel()
        stopFallback()
    }

    /** "Vypnout rádio". */
    fun turnOff() {
        done()
        cancelSnooze()
        context.app.radio.pause()
    }

    /** "Vyzkoušet za 10 sekund". */
    fun test() {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val at = Instant.now().plusSeconds(10).toEpochMilli()
        val intent = fireIntent(ACTION_SNOOZE_END, 2)
        if (canScheduleExact()) alarms.setAlarmClock(AlarmManager.AlarmClockInfo(at, openApp(3)), intent)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
    }

    // MARK: Notifications

    private fun channels(manager: NotificationManager, res: Context) {
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, res.getString(R.string.alarmTitle), NotificationManager.IMPORTANCE_HIGH).apply { setSound(null, null) }
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_FALLBACK, res.getString(R.string.alarmTitle), NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
                )
            }
        )
    }

    private fun notifyRinging(fallback: Boolean) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val res = context.inLanguage(context.app.language.language.value)
        channels(manager, res)
        val english = context.app.language.language.value.isEnglish
        val show = context.app.schedule.currentShow()?.localizedName(english)
        val builder = NotificationCompat.Builder(context, if (fallback) CHANNEL_FALLBACK else CHANNEL)
            .setSmallIcon(R.drawable.tab_icon_radio)
            .setContentTitle(res.getString(R.string.alarmGoodMorning))
            .setContentText(show?.let { res.getString(R.string.alarmShowAt, it) } ?: res.getString(R.string.alarmTitle))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(openApp(4))
            .setDeleteIntent(action(ACTION_DONE, 7))
            .setAutoCancel(true)
        if (canSnooze) builder.addAction(0, res.getString(R.string.alarmSnoozeFor, _settings.value.snoozeMinutes), action(ACTION_SNOOZE, 5))
        builder.addAction(0, res.getString(R.string.alarmTurnOffRadio), action(ACTION_TURN_OFF, 6))
        val notification = builder.build()
        // The phone's alarm sound over and over until dismissed, when the stream didn't start.
        if (fallback) notification.flags = notification.flags or NotificationCompat.FLAG_INSISTENT
        runCatching { manager.notify(NOTIFICATION_ID, notification) }
    }

    private fun notifySnoozed(until: Instant) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val res = context.inLanguage(context.app.language.language.value)
        channels(manager, res)
        val time = until.atZone(zone()).toLocalTime()
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.tab_icon_radio)
            .setContentTitle(res.getString(R.string.alarmSnoozedTitle))
            .setContentText(res.getString(R.string.alarmSnoozedUntil, "%d:%02d".format(time.hour, time.minute)))
            .setOngoing(true)
            .setContentIntent(openApp(4))
            .addAction(0, res.getString(R.string.alarmCancel), action(ACTION_CANCEL_SNOOZE, 8))
            .build()
        runCatching { manager.notify(NOTIFICATION_ID, notification) }
    }

    private fun stopFallback() {
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }

    private fun fireIntent(action: String, code: Int) = PendingIntent.getBroadcast(
        context, code, Intent(context, RadioAlarmReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun action(action: String, code: Int) = fireIntent(action, code)

    private fun openApp(code: Int) = PendingIntent.getActivity(
        context, 100 + code, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    companion object {
        private const val SETTINGS = "settings"
        private const val CHANNEL = "radio-alarm"
        private const val CHANNEL_FALLBACK = "radio-alarm-sound"
        private const val NOTIFICATION_ID = 6_30
        private const val FALLBACK_AFTER_MS = 20_000L
        const val MAX_SNOOZES = 3
        const val ACTION_FIRE = "cz.slowdownradijo.app.ALARM_FIRE"
        const val ACTION_SNOOZE_END = "cz.slowdownradijo.app.ALARM_SNOOZE_END"
        const val ACTION_SNOOZE = "cz.slowdownradijo.app.ALARM_SNOOZE"
        const val ACTION_TURN_OFF = "cz.slowdownradijo.app.ALARM_TURN_OFF"
        const val ACTION_DONE = "cz.slowdownradijo.app.ALARM_DONE"
        const val ACTION_CANCEL_SNOOZE = "cz.slowdownradijo.app.ALARM_CANCEL_SNOOZE"

        /** The next ring after [after] in [zone]; pure, for tests. */
        fun nextFire(after: Instant, settings: RadioAlarmSettings, zone: ZoneId): Instant? {
            val start = after.atZone(zone)
            val time = LocalTime.of(settings.hour, settings.minute)
            for (offset in 0..7L) {
                val day: LocalDate = start.toLocalDate().plusDays(offset)
                if (settings.weekdays.isNotEmpty() && day.dayOfWeek.value !in settings.weekdays) continue
                val at = ZonedDateTime.of(day, time, zone)
                if (at.isAfter(start)) return at.toInstant()
            }
            return null
        }

        /** Weekdays Monday first, as in the sheet. */
        val WEEK: List<DayOfWeek> = DayOfWeek.entries
    }
}

/** The alarm, its notification's buttons, and re-planning after a reboot or an app update. */
class RadioAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarm = context.app.radioAlarm
        when (intent.action) {
            RadioAlarm.ACTION_FIRE, RadioAlarm.ACTION_SNOOZE_END -> alarm.fire()
            RadioAlarm.ACTION_SNOOZE -> alarm.snooze()
            RadioAlarm.ACTION_TURN_OFF -> alarm.turnOff()
            RadioAlarm.ACTION_DONE -> alarm.done()
            RadioAlarm.ACTION_CANCEL_SNOOZE -> alarm.cancelSnooze()
            else -> alarm.reschedule()
        }
    }
}
