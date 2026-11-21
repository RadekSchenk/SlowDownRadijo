package cz.slowdownradijo.app.contests

import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

/**
 * A sample contest without the server, the same as `ContestDemo.swift`: for the
 * screenshot tests and for trying the screens in a debug build.
 */
object ContestDemo {
    fun contest(english: Boolean = false, now: Instant = Instant.now(), entered: Boolean = false): ContestService.Contest {
        val zone = ZoneId.of("Europe/Prague")
        val end = now.atZone(zone).toLocalDate().plusDays(6).atTime(LocalTime.of(23, 59)).atZone(zone).toInstant()
        return ContestService.Contest(
            id = 1,
            title = if (english) "Win 2 tickets to Slow Down Fest 2027" else "Vyhraj 2 lístky na Slow Down Fest 2027",
            body = if (english) {
                "Slow Down Fest returns to Ještěd in summer 2027 and we have two pairs of tickets for listeners. Answer the question about our programme and leave your phone number. After the contest we draw two winners from the right answers, call them and announce them on Monday's Morning Coffee."
            } else {
                "Slow Down Fest se v létě 2027 vrací na Ještěd a my máme pro posluchače dva páry lístků. Odpověz na otázku o našem programu a nech nám telefon. Po skončení soutěže vylosujeme dva výherce ze správných odpovědí, zavoláme jim a oznámíme je v pondělní Morning Coffee."
            },
            question = if (english) "Which show is on Sunday at 14:00?" else "Který pořad hraje v neděli od 14:00?",
            answerType = "choice",
            options = listOf("Weekend Aftertaste", "Diggin’ Time", "Noční linka"),
            prize = if (english) "2× two tickets" else "2× dvě vstupenky",
            winnersCount = 2,
            rulesUrl = "https://slowdownradijo.cz/pravidla-soutezi/",
            endsAtText = end.toString(),
            myStatus = if (entered) "entered" else null,
            myEntry = if (entered) ContestService.Entry("B", "+420777123456", now.minus(Duration.ofHours(26)).toString()) else null,
        )
    }

    fun overview(now: Instant = Instant.now()): ContestAdmin.Overview {
        val c = contest(now = now)
        fun ago(days: Long) = now.minus(Duration.ofDays(days)).toString()
        return ContestAdmin.Overview(
            current = ContestAdmin.Summary(
                id = 1, title = c.title, prize = c.prize, winnersCount = 2, startsAtText = ago(3), endsAtText = c.endsAtText,
                isRunning = true, entries = 128, correct = 97, dismissed = 41,
            ),
            previous = listOf(
                ContestAdmin.Summary(
                    id = 2, title = "Vinyl Khruangbin – Mordechai", answerType = "text", prize = "Vinyl", startsAtText = ago(30),
                    endsAtText = ago(19), drawnAtText = ago(18), entries = 214, dismissed = 12, winners = 1,
                ),
                ContestAdmin.Summary(
                    id = 3, title = "Lístky na Prague Sound Days", prize = "2× lístky", winnersCount = 2, startsAtText = ago(50),
                    endsAtText = ago(40), entries = 156, correct = 120, dismissed = 30,
                ),
            ),
        )
    }

    fun detail(drawn: Boolean, now: Instant = Instant.now()): ContestAdmin.Detail {
        val c = contest(now = now)
        fun hoursAgo(h: Long) = now.minus(Duration.ofHours(h)).toString()
        val winners = if (drawn) listOf(
            ContestAdmin.Person("vinylovy_tom", "B", phone = "+420777123456", drawnAtText = now.toString()),
            ContestAdmin.Person("jana_z_letne", "B", phone = "+420731908117", drawnAtText = now.toString()),
        ) else emptyList()
        return ContestAdmin.Detail(
            ContestAdmin.Summary(
                id = 3, title = c.title, prize = c.prize, winnersCount = 2, startsAtText = hoursAgo(9 * 24), endsAtText = hoursAgo(48),
                drawnAtText = if (drawn) now.toString() else null, entries = 342, correct = 261, dismissed = 41, winners = winners.size,
            ),
            ContestAdmin.DetailData(
                question = c.question, options = c.options, correctOption = 1,
                distribution = listOf(ContestAdmin.Bucket("A", 51), ContestAdmin.Bucket("B", 261), ContestAdmin.Bucket("C", 30)),
                entries = listOf(
                    ContestAdmin.Person("vinylovy_tom", "B", true, "+420777123456", hoursAgo(50)),
                    ContestAdmin.Person("kafe_s_mlekem", "A", false, "+420604555210", hoursAgo(53)),
                    ContestAdmin.Person("jana_z_letne", "B", true, "+420731908117", hoursAgo(80)),
                ),
                winners = winners,
            ),
        )
    }
}
