package cz.slowdownradijo.app.l10n

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * The L10n.swift entries with logic in them, which
 * tools/android/l10n_to_strings.py leaves out of strings.xml. Keep these in
 * step with L10n.swift by hand; every other string comes from strings.xml.
 */
object L10nLogic {
    /** "1h 29 min" / "1h 29m" */
    fun durationShort(english: Boolean, hours: Int, minutes: Int): String = when {
        minutes == 0 -> "${hours}h"
        english -> "${hours}h ${minutes}m"
        else -> "${hours}h $minutes min"
    }

    /** Time left to the minute: "27 min", "1 h 27 min" (EN "27m", "1h 27m"). */
    fun remaining(english: Boolean, hours: Int, minutes: Int): String = if (english) {
        if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
    } else {
        if (hours > 0) "$hours h $minutes min" else "$minutes min"
    }

    /** A countdown to the second: "9 min 56 s", "1 h 27 min 36 s" (EN "9m 56s"). */
    fun countdown(english: Boolean, hours: Int, minutes: Int, seconds: Int): String = if (english) {
        when {
            hours > 0 -> "${hours}h ${minutes}m ${seconds}s"
            minutes > 0 -> "${minutes}m ${seconds}s"
            else -> "${seconds}s"
        }
    } else {
        when {
            hours > 0 -> "$hours h $minutes min $seconds s"
            minutes > 0 -> "$minutes min $seconds s"
            else -> "$seconds s"
        }
    }

    /** Toast after turning a show's reminder on. */
    fun reminderOnToast(english: Boolean, show: String, next: String?): String = if (english) {
        val base = "We'll let you know when $show starts."
        if (next != null) "$base Next: $next." else base
    } else {
        val base = "Dáme ti vědět, až začne $show."
        if (next != null) "$base Nejbližší: $next." else base
    }

    /** Subtitle of the Settings row. */
    fun showRemindersSummary(english: Boolean, count: Int): String = if (english) {
        when (count) {
            0 -> "Off"
            1 -> "On for 1 show"
            else -> "On for $count shows"
        }
    } else {
        when (count) {
            0 -> "Vypnuto"
            1 -> "Zapnuto u 1 pořadu"
            else -> "Zapnuto u $count pořadů"
        }
    }

    /** Two-letter weekday, Sunday-first 1...7. */
    fun shortDayName(english: Boolean, weekday: Int): String {
        val cs = listOf("Ne", "Po", "Út", "St", "Čt", "Pá", "So")
        val en = listOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        return (if (english) en else cs).getOrNull(weekday - 1) ?: "?"
    }

    /** Under an earlier song on the home screen: "před 6 min". */
    fun playedAgo(english: Boolean, minutes: Int): String {
        val m = maxOf(minutes, 1)
        val duration = remaining(english, m / 60, m % 60)
        return if (english) "$duration ago" else "před $duration"
    }

    /** A long date in the app's language, not the phone's. */
    fun formattedDate(english: Boolean, date: LocalDate): String =
        date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(if (english) Locale.US else Locale.forLanguageTag("cs-CZ")))
}
