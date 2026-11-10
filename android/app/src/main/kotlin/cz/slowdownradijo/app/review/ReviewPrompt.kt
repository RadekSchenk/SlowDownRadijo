package cz.slowdownradijo.app.review

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * When to ask for a rating, as `ReviewPrompt.swift`: a listener who has had
 * the app a week and listened at least 10 minutes on 3 days of the last 60;
 * at most 3 times, 120 days apart. Google Play shows its own dialog (or
 * nothing, by its own quota); the app never knows the answer.
 */
class ReviewPrompt(
    context: Context,
    private val now: () -> Instant = Instant::now,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
) {
    private val prefs = context.getSharedPreferences("reviewPrompt", Context.MODE_PRIVATE)
    private val _shouldAsk = MutableStateFlow(false)
    val shouldAsk: StateFlow<Boolean> = _shouldAsk.asStateFlow()

    init {
        if (!prefs.contains(FIRST_OPEN)) prefs.edit().putLong(FIRST_OPEN, now().epochSecond).apply()
        evaluate()
    }

    private fun listeningByDay(): MutableMap<String, Long> =
        prefs.all.filterKeys { it.startsWith(DAY) }.mapValues { (it.value as? Long) ?: 0L }.mapKeys { it.key.removePrefix(DAY) }.toMutableMap()

    /** Credits [seconds] of listening to today. */
    fun addListening(seconds: Long) {
        if (seconds <= 0) return
        val today = LocalDate.ofInstant(now(), zone())
        val editor = prefs.edit()
        val key = DAY + today
        editor.putLong(key, prefs.getLong(key, 0) + seconds)
        val oldest = today.minusDays(WINDOW_DAYS)
        listeningByDay().keys.filter { LocalDate.parse(it).isBefore(oldest) }.forEach { editor.remove(DAY + it) }
        editor.apply()
        evaluate()
    }

    fun didAsk() {
        prefs.edit().putLong(LAST_ASKED, now().epochSecond).putInt(TIMES_ASKED, prefs.getInt(TIMES_ASKED, 0) + 1).apply()
        _shouldAsk.value = false
    }

    fun evaluate() {
        val at = now()
        val firstOpen = Instant.ofEpochSecond(prefs.getLong(FIRST_OPEN, at.epochSecond))
        val lastAsked = if (prefs.contains(LAST_ASKED)) Instant.ofEpochSecond(prefs.getLong(LAST_ASKED, 0)) else null
        val qualifying = listeningByDay().values.count { it >= QUALIFYING_DAY_SECONDS }
        _shouldAsk.value = prefs.getInt(TIMES_ASKED, 0) < MAXIMUM_ASKS &&
            Duration.between(firstOpen, at) >= MINIMUM_AGE &&
            (lastAsked == null || Duration.between(lastAsked, at) >= REST) &&
            qualifying >= QUALIFYING_DAYS
    }

    /** Google Play's in-app review over [activity]. */
    fun ask(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
        }
        didAsk()
    }

    private companion object {
        const val FIRST_OPEN = "firstOpen"
        const val LAST_ASKED = "lastAsked"
        const val TIMES_ASKED = "timesAsked"
        const val DAY = "day."
        val MINIMUM_AGE: Duration = Duration.ofDays(7)
        const val QUALIFYING_DAY_SECONDS = 10 * 60L
        const val QUALIFYING_DAYS = 3
        const val WINDOW_DAYS = 60L
        val REST: Duration = Duration.ofDays(120)
        const val MAXIMUM_ASKS = 3
    }
}
