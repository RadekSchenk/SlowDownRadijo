package cz.slowdownradijo.app.review

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

@RunWith(RobolectricTestRunner::class)
class ReviewPromptTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private var now: Instant = Instant.parse("2026-01-01T12:00:00Z")
    private fun prompt() = ReviewPrompt(context, { now }, { ZoneOffset.UTC })
    private fun days(n: Long) { now = now.plus(Duration.ofDays(n)) }

    @Test fun asksAfterAWeekAndThreeListeningDays() {
        val p = prompt()
        repeat(3) { p.addListening(10 * 60); days(1) }
        assertFalse("not before a week", p.shouldAsk.value)
        days(4); p.evaluate()
        assertTrue(p.shouldAsk.value)
    }

    @Test fun shortDaysDoNotCount() {
        val p = prompt()
        repeat(5) { p.addListening(9 * 60); days(1) }
        days(7); p.evaluate()
        assertFalse(p.shouldAsk.value)
    }

    @Test fun minutesAddUpWithinADay() {
        val p = prompt()
        repeat(3) { repeat(10) { p.addListening(60) }; days(1) }
        days(7); p.evaluate()
        assertTrue(p.shouldAsk.value)
    }

    @Test fun oldDaysFallOutOfTheWindow() {
        val p = prompt()
        repeat(3) { p.addListening(10 * 60); days(1) }
        days(61); p.addListening(1)
        assertFalse(p.shouldAsk.value)
    }

    @Test fun restsBetweenAsksAndStopsAfterThree() {
        val p = prompt()
        days(7)
        repeat(3) {
            repeat(3) { p.addListening(10 * 60); days(1) }
            assertTrue(p.shouldAsk.value)
            p.didAsk()
            assertFalse(p.shouldAsk.value)
            days(100); p.evaluate()
            assertFalse("120 days between asks", p.shouldAsk.value)
            days(20)
        }
        repeat(3) { p.addListening(10 * 60); days(1) }
        assertFalse("at most three", p.shouldAsk.value)
    }

    @Test fun firstOpenIsKept() {
        prompt()
        days(7)
        val p = prompt()
        repeat(3) { p.addListening(10 * 60); days(1) }
        assertTrue(p.shouldAsk.value)
    }
}
