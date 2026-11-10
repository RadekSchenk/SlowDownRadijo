package cz.slowdownradijo.app.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import cz.slowdownradijo.app.MainActivity
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.ScheduleStore.Companion.STATION_ZONE
import cz.slowdownradijo.app.data.ScheduleStore.Companion.weekdaySundayFirst
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.inLanguage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant
import java.time.LocalDate
import java.time.ZonedDateTime

/**
 * "Právě začíná" notifications for the shows the listener follows, as
 * `ShowReminderStore.swift`. One alarm at a time: for the next start of a
 * followed show; when it rings, [ReminderReceiver] posts the notification
 * and sets the alarm for the start after it. The programme's changes (a
 * special on the web) and the language re-plan it.
 */
class ShowReminders(private val context: Context, private val schedule: ScheduleStore) {
    private val prefs = context.getSharedPreferences("reminders", Context.MODE_PRIVATE)
    private val _followed = MutableStateFlow(prefs.getStringSet(KEY, emptySet())!!.toSet())
    val followed: StateFlow<Set<String>> = _followed.asStateFlow()

    fun isFollowing(show: Show) = show.id in _followed.value

    fun setFollowing(show: Show, follow: Boolean) {
        _followed.value = if (follow) _followed.value + show.id else _followed.value - show.id
        save()
        reschedule()
    }

    fun unfollowAll() {
        _followed.value = emptySet()
        save()
        reschedule()
    }

    private fun save() = prefs.edit().putStringSet(KEY, _followed.value).apply()

    /** Every show of the week once, by title, for the settings list. */
    val allShows: List<Show>
        get() = schedule.days.value.flatMap { it.shows }.distinctBy { it.id }.sortedBy { it.displayTitle.lowercase() }

    fun notificationsAllowed(): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)

    /** "dnes v 9:00", "zítra v 9:00", "St v 9:00". */
    fun nextAiringLabel(show: Show, english: Boolean, now: Instant = Instant.now()): String? {
        val start = upcomingStarts(setOf(show.id), now).firstOrNull()?.second ?: return null
        val today = now.atZone(STATION_ZONE).toLocalDate()
        val date = start.atZone(STATION_ZONE).toLocalDate()
        val res = context.inLanguage(if (english) cz.slowdownradijo.app.l10n.AppLanguage.EN else cz.slowdownradijo.app.l10n.AppLanguage.CS).resources
        val day = when (date) {
            today -> res.getString(R.string.today).lowercase()
            today.plusDays(1) -> res.getString(R.string.tomorrow)
            else -> L10nLogic.shortDayName(english, start.atZone(STATION_ZONE).weekdaySundayFirst())
        }
        return res.getString(R.string.nextAiring, day, show.start)
    }

    /** Starts of followed shows after [now], skipping a block that only continues the one before it. */
    fun upcomingStarts(ids: Set<String>, now: Instant): List<Pair<Show, Instant>> {
        if (ids.isEmpty()) return emptyList()
        val today = now.atZone(STATION_ZONE).toLocalDate()
        val result = mutableListOf<Pair<Show, Instant>>()
        var previous: Pair<String, Instant>? = null
        // From yesterday, so a show running on past midnight counts as a continuation.
        for (offset in -1L until LOOKAHEAD_DAYS) {
            val date = today.plusDays(offset)
            val day = schedule.day(date.atStartOfDay(STATION_ZONE).weekdaySundayFirst()) ?: continue
            val slots = day.shows.mapNotNull { show ->
                val start = at(date, show.start, endOfDay = false) ?: return@mapNotNull null
                val end = at(date, show.end, endOfDay = true) ?: return@mapNotNull null
                Triple(show, start, end)
            }.sortedBy { it.second }
            for ((show, start, end) in slots) {
                val continues = previous?.let { it.first == show.id && it.second == start } ?: false
                previous = show.id to end
                if (!continues && show.id in ids && start.isAfter(now)) result += show to start
            }
        }
        return result.sortedBy { it.second }
    }

    private fun at(date: LocalDate, time: String, endOfDay: Boolean): Instant? {
        val minutes = ScheduleStore.minutes(time) ?: return null
        if (endOfDay && (minutes == 0 || minutes == 1440)) return date.plusDays(1).atStartOfDay(STATION_ZONE).toInstant()
        if (minutes >= 1440) return null
        return ZonedDateTime.of(date.atStartOfDay(), STATION_ZONE).plusMinutes(minutes.toLong()).toInstant()
    }

    /** The alarm for the next followed start, or none. */
    fun reschedule(now: Instant = Instant.now()) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = alarmIntent()
        alarms.cancel(intent)
        val next = upcomingStarts(_followed.value, now).firstOrNull()?.second ?: return
        val at = next.toEpochMilli()
        // Exact when the system lets us; otherwise within a minute of the start.
        if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        } else {
            alarms.setWindow(AlarmManager.RTC_WAKEUP, at, 60_000, intent)
        }
    }

    private fun alarmIntent() = PendingIntent.getBroadcast(
        context, 0, Intent(context, ReminderReceiver::class.java).setAction(ACTION_ALARM),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Posts "Právě začíná" for followed shows starting around [now]. */
    fun notifyStarting(now: Instant = Instant.now()) {
        if (!notificationsAllowed()) return
        val starting = upcomingStarts(_followed.value, now.minusSeconds(5 * 60))
            .filter { !it.second.isAfter(now.plusSeconds(60)) }
        if (starting.isEmpty()) return
        val res = context.inLanguage(context.app.language.language.value)
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, res.getString(R.string.showRemindersTitle), NotificationManager.IMPORTANCE_HIGH)
        )
        val english = context.app.language.language.value.isEnglish
        for ((show, start) in starting) {
            val id = (show.id.hashCode() xor start.epochSecond.toInt())
            fun open(listen: Boolean) = PendingIntent.getActivity(
                context, id * 2 + if (listen) 1 else 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(EXTRA_SHOW_ID, show.id)
                    .putExtra(EXTRA_LISTEN, listen),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val notification = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.tab_icon_radio)
                .setContentTitle(res.getString(R.string.showStartingTitle))
                .setContentText(show.localizedName(english))
                .setAutoCancel(true)
                .setContentIntent(open(listen = false))
                .addAction(0, res.getString(R.string.listenAction), open(listen = true))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()
            runCatching { manager.notify(id, notification) }
        }
    }

    companion object {
        private const val KEY = "showReminders.followed"
        private const val LOOKAHEAD_DAYS = 14L
        const val CHANNEL = "show-start"
        const val ACTION_ALARM = "cz.slowdownradijo.app.SHOW_START"
        const val EXTRA_SHOW_ID = "showID"
        const val EXTRA_LISTEN = "listen"
    }
}

/** The reminder alarm, and re-planning after a reboot or an app update. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminders = context.app.reminders
        if (intent.action == ShowReminders.ACTION_ALARM) reminders.notifyStarting()
        // The next one; a minute on, so the show that just started isn't picked again.
        reminders.reschedule(Instant.now().plusSeconds(60))
    }
}
