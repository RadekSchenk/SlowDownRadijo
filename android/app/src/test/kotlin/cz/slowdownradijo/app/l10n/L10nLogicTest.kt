package cz.slowdownradijo.app.l10n

import org.junit.Assert.assertEquals
import org.junit.Test

/** The same cases as the L10n.swift functions they port. */
class L10nLogicTest {
    @Test fun durations() {
        assertEquals("1h 29 min", L10nLogic.durationShort(false, 1, 29))
        assertEquals("1h 29m", L10nLogic.durationShort(true, 1, 29))
        assertEquals("2h", L10nLogic.durationShort(true, 2, 0))
        assertEquals("1 h 27 min", L10nLogic.remaining(false, 1, 27))
        assertEquals("27m", L10nLogic.remaining(true, 0, 27))
        assertEquals("9 min 56 s", L10nLogic.countdown(false, 0, 9, 56))
        assertEquals("1h 27m 36s", L10nLogic.countdown(true, 1, 27, 36))
        assertEquals("56 s", L10nLogic.countdown(false, 0, 0, 56))
    }

    @Test fun playedAgo() {
        assertEquals("před 1 min", L10nLogic.playedAgo(false, 0))
        assertEquals("1h 5m ago", L10nLogic.playedAgo(true, 65))
    }

    @Test fun reminders() {
        assertEquals("Zapnuto u 3 pořadů", L10nLogic.showRemindersSummary(false, 3))
        assertEquals("On for 1 show", L10nLogic.showRemindersSummary(true, 1))
        assertEquals("Dáme ti vědět, až začne Bass Time. Nejbližší: Po v 20:00.", L10nLogic.reminderOnToast(false, "Bass Time", "Po v 20:00"))
        assertEquals("We'll let you know when Bass Time starts.", L10nLogic.reminderOnToast(true, "Bass Time", null))
    }

    @Test fun weekdays() {
        assertEquals("Ne", L10nLogic.shortDayName(false, 1))
        assertEquals("Sa", L10nLogic.shortDayName(true, 7))
    }
}
