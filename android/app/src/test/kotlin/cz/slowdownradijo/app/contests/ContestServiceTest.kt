package cz.slowdownradijo.app.contests

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** The same rules as `contest_normalize_phone` and `admin_create_contest` in 028_contests.sql. */
class ContestServiceTest {
    @Test fun czechNumbers() {
        assertEquals("+420777123456", ContestService.normalizedPhone("777123456"))
        assertEquals("+420777123456", ContestService.normalizedPhone("+420 777 123 456"))
        assertEquals("+420777123456", ContestService.normalizedPhone("00420 777-123-456"))
        assertNull(ContestService.normalizedPhone("777 12"))
        assertNull(ContestService.normalizedPhone("+420 12"))
        assertNull(ContestService.normalizedPhone(""))
    }

    @Test fun foreignNumbers() {
        assertEquals("+421905123456", ContestService.normalizedPhone("+421 905 123 456"))
        assertEquals("+4915123456789", ContestService.normalizedPhone("0049 1512 3456789"))
        assertNull(ContestService.normalizedPhone("+0123456789"))
        assertNull(ContestService.normalizedPhone("12345678"))
    }

    @Test fun timestamps() {
        val expected = Instant.parse("2026-11-30T22:59:00Z")
        assertEquals(expected, ContestService.parseInstant("2026-11-30T23:59:00+01:00"))
        assertEquals(expected, ContestService.parseInstant("2026-11-30 23:59:00+01"))
        assertEquals(Instant.parse("2026-11-21T19:44:04.80205Z"), ContestService.parseInstant("2026-11-21T20:44:04.80205+01:00"))
    }

    @Test fun infoboxOnlyForARunningContestNotEnteredOrClosed() {
        val now = Instant.parse("2026-11-21T12:00:00Z")
        val contest = ContestDemo.contest(now = now)
        val service = ContestService::class
        assertTrue(contest.isRunning(now))
        assertEquals(false, ContestDemo.contest(now = now, entered = true).myStatus == null)
        assertEquals(false, contest.isRunning(contest.endsAt.plusSeconds(1)))
        assertTrue(service.simpleName == "ContestService")
    }

    @Test fun draftChecks() {
        val now = Instant.parse("2026-11-21T12:00:00Z")
        val empty = ContestAdmin.Draft(endsAt = now)
        assertEquals(
            setOf(
                ContestAdmin.Draft.Field.TITLE, ContestAdmin.Draft.Field.BODY, ContestAdmin.Draft.Field.QUESTION,
                ContestAdmin.Draft.Field.OPTIONS, ContestAdmin.Draft.Field.PRIZE, ContestAdmin.Draft.Field.RULES, ContestAdmin.Draft.Field.END,
            ),
            empty.problems(now),
        )
        val ok = ContestAdmin.Draft(
            title = "Vyhraj lístky", body = "Text soutěže je tady.", question = "Který pořad?",
            options = listOf("A", "B", "C"), correctOption = 1, prize = "2× lístky", rulesUrl = "slowdownradijo.cz/pravidla",
            endsAt = ContestAdmin.Draft.defaultEnd(now),
        )
        assertEquals(emptySet<ContestAdmin.Draft.Field>(), ok.problems(now))
        assertEquals(emptySet<ContestAdmin.Draft.Field>(), ok.copy(isChoice = false, options = listOf("", "", ""), correctOption = null).problems(now))
    }

    @Test fun defaultEndIsSundayNight() {
        val end = ContestAdmin.Draft.defaultEnd(Instant.parse("2026-11-21T12:00:00Z")) // Saturday
        assertEquals(Instant.parse("2026-11-29T22:59:00Z"), end)
    }

    @Test fun phoneFormat() {
        assertEquals("+420 777 123 456", ContestFormat.phone("+420777123456"))
        assertEquals("+421905123456", ContestFormat.phone("+421905123456"))
    }
}
