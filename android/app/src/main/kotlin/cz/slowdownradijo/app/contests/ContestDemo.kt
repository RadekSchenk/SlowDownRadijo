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
            title = if (english) "Win Thundercat – Distracted on vinyl" else "Vyhraj vinyl Thundercat – Distracted",
            body = if (english) {
                "Another contest for our Slowriders: Distracted on vinyl, Thundercat's fifth and latest album, with guests including Tame Impala, Mac Miller, Lil Yachty and Flying Lotus. Answer the question and leave your phone number. We draw the winner on the Monday after the contest, live on Morning Coffee between 7 and 9."
            } else {
                "Pro naše Slowriders tu máme další soutěž: vinyl Distracted, páté a nejnovější album Thundercata. Na desce hostují Tame Impala, Mac Miller, Lil Yachty, Flying Lotus a další. Odpověz na otázku a nech nám telefon. Výherce vylosujeme v pondělí po skončení soutěže v Morning Coffee mezi 7. a 9. hodinou."
            },
            question = if (english) "Which producer and long-time Thundercat collaborator guests on Distracted?" else "Který producent a dlouholetý spolupracovník Thundercata hostuje na albu Distracted?",
            answerType = "choice",
            options = listOf("Moby", "Flying Lotus", "Fatboy Slim"),
            prize = if (english) "Distracted on vinyl" else "Vinyl Distracted",
            winnersCount = 1,
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
                id = 1, title = c.title, prize = c.prize, winnersCount = 1, startsAtText = ago(3), endsAtText = c.endsAtText,
                isRunning = true, entries = 128, correct = 97, dismissed = 41,
            ),
            previous = listOf(
                ContestAdmin.Summary(
                    id = 2, title = "Vinyl Khruangbin – A LA SALA", answerType = "text", prize = "Vinyl", startsAtText = ago(30),
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
        ) else emptyList()
        return ContestAdmin.Detail(
            ContestAdmin.Summary(
                id = 3, title = c.title, prize = c.prize, winnersCount = 1, startsAtText = hoursAgo(9 * 24), endsAtText = hoursAgo(48),
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
