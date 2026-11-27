package cz.slowdownradijo.app.chat

import cz.slowdownradijo.app.chat.ChatTimeline.Row
import cz.slowdownradijo.app.l10n.L10nLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class ChatTimelineTest {
    private val zone = ZoneId.of("Europe/Prague")
    private val now = Instant.parse("2026-11-18T09:00:00Z") // 10:00 in Prague
    private val words = ChatTimeline.Words("Dnes", "Včera", "Hudba bez moderace", "Smazaný účet", english = false)
    private val shows = mapOf("morning-coffee" to "07:00", "nocni-linka" to "22:00", "weekend-aftertaste" to "20:00")

    private fun msg(id: Long, at: String, body: String, show: String? = "morning-coffee", title: String? = "Morning Coffee", user: String = "u$id", name: String = "user$id") =
        ChatMessage(id = id, userId = user, authorName = name, body = body, showId = show, showTitle = title, createdAtText = at)

    private fun rows(messages: List<ChatMessage>, hidden: Set<String> = emptySet(), outgoing: List<OutgoingChatMessage> = emptyList()) =
        ChatTimeline.rows(messages, words, outgoing, "morning-coffee" to "Morning Coffee", hidden, now, zone) { id, title, _ ->
            id?.let { ChatTimeline.ShowLabel(shows[it], title ?: it) }
        }

    private fun dividers(rows: List<Row>) = rows.filterIsInstance<Row.Divider>().map { it.text }

    @Test fun dividerOnlyBeforeFirstMessageOfDayAndShow() {
        val r = rows(listOf(
            msg(1, "2026-11-17T19:10:00Z", "Dušičková neděle", "weekend-aftertaste", "Weekend Aftertaste"),
            msg(2, "2026-11-17T19:30:00Z", "Anderson nikdy nezklame", "weekend-aftertaste", "Weekend Aftertaste"),
            msg(3, "2026-11-17T21:41:00Z", "Noc", "nocni-linka", "Noční linka"),
            msg(4, "2026-11-18T06:10:00Z", "Dobré ráno"),
        ))
        assertEquals(listOf("Včera · 20:00 Weekend Aftertaste", "22:00 Noční linka", "Dnes · 07:00 Morning Coffee"), dividers(r))
        assertEquals(7, r.size)
    }

    @Test fun emptyDaysAreSkipped() {
        val r = rows(listOf(msg(1, "2026-11-10T08:00:00Z", "Ahoj"), msg(2, "2026-11-18T06:10:00Z", "Ahoj")))
        assertEquals(listOf("Út 10. 11. · 07:00 Morning Coffee", "Dnes · 07:00 Morning Coffee"), dividers(r))
    }

    @Test fun messageOutsideAnyShow() {
        val r = rows(listOf(msg(1, "2026-11-18T03:00:00Z", "Ahoj", show = null, title = null)))
        assertEquals(listOf("Dnes · Hudba bez moderace"), dividers(r))
    }

    @Test fun sameEmojiWithinAMinuteMerges() {
        val r = rows(listOf(
            msg(1, "2026-11-18T06:10:00Z", "🔥", name = "nela"),
            msg(2, "2026-11-18T06:10:30Z", "🔥", name = "marty"),
            msg(3, "2026-11-18T06:11:20Z", "🔥", name = "nela"),
            msg(4, "2026-11-18T06:11:40Z", "🔥", name = "tom"),
            msg(5, "2026-11-18T06:20:00Z", "🔥", name = "jana"), // more than 60 s later
            msg(6, "2026-11-18T06:20:10Z", "❤️", name = "jana"),
        ))
        val emoji = r.filterIsInstance<Row.Emoji>().single()
        assertEquals(4, emoji.count)
        assertEquals(listOf("nela", "marty", "tom"), emoji.names)
        assertEquals(listOf(5L, 6L), r.filterIsInstance<Row.Message>().map { it.message.id })
    }

    @Test fun textBetweenEmojiBreaksTheGroup() {
        val r = rows(listOf(
            msg(1, "2026-11-18T06:10:00Z", "🔥"),
            msg(2, "2026-11-18T06:10:10Z", "Paráda"),
            msg(3, "2026-11-18T06:10:20Z", "🔥"),
        ))
        assertEquals(0, r.filterIsInstance<Row.Emoji>().size)
        assertEquals(3, r.filterIsInstance<Row.Message>().size)
    }

    @Test fun hiddenListenersAreLeftOut() {
        val r = rows(listOf(msg(1, "2026-11-18T06:10:00Z", "Ahoj", user = "a"), msg(2, "2026-11-18T06:11:00Z", "Spam", user = "b")), hidden = setOf("b"))
        assertEquals(listOf(1L), r.filterIsInstance<Row.Message>().map { it.message.id })
    }

    @Test fun firstOwnMessageOfTheDayOpensTheShow() {
        val r = rows(
            listOf(msg(1, "2026-11-17T19:10:00Z", "Večer", "weekend-aftertaste", "Weekend Aftertaste")),
            outgoing = listOf(OutgoingChatMessage(id = "x", body = "Dobré ráno 👋", createdAt = now)),
        )
        assertEquals(listOf("Včera · 20:00 Weekend Aftertaste", "Dnes · 07:00 Morning Coffee"), dividers(r))
        assertEquals("x", (r.last() as Row.Outgoing).message.id)
    }

    @Test fun singleEmojiDetection() {
        assertEquals("🔥", msg(1, "2026-11-18T06:10:00Z", " 🔥 ").singleEmoji)
        assertEquals("❤️", msg(1, "2026-11-18T06:10:00Z", "❤️").singleEmoji)
        assertEquals("👋🏽", msg(1, "2026-11-18T06:10:00Z", "👋🏽").singleEmoji)
        assertNull(msg(1, "2026-11-18T06:10:00Z", "🔥🔥").singleEmoji)
        assertNull(msg(1, "2026-11-18T06:10:00Z", "a").singleEmoji)
        assertNull(msg(1, "2026-11-18T06:10:00Z", "1").singleEmoji)
    }

    @Test fun parsesBothTimestampShapes() {
        assertEquals(Instant.parse("2026-11-18T06:10:00.123Z"), ChatMessage.parse("2026-11-18T06:10:00.123+00:00"))
        assertEquals(Instant.parse("2026-11-18T06:10:00Z"), ChatMessage.parse("2026-11-18 06:10:00+00"))
    }

    @Test fun timeLineForTheMenu() {
        val m = msg(1, "2026-11-17T22:41:00Z", "Noc", "nocni-linka", "Noční linka")
        assertEquals("Včera 23:41 · Noční linka", ChatTimeline.timeLine(m, now, zone, words))
    }

    @Test fun daysPlural() {
        assertEquals("den", L10nLogic.slowrideDays(false, 1))
        assertEquals("dny", L10nLogic.slowrideDays(false, 3))
        assertEquals("dní", L10nLogic.slowrideDays(false, 12))
        assertEquals("days", L10nLogic.slowrideDays(true, 12))
    }

    @Test fun hostIdsFromProgrammeNames() {
        assertEquals("dj-pufaz", ChatAdmin.hostId("DJ Pufaz"))
        assertEquals("don-hoblinon", ChatAdmin.hostId("Don Hobliňon"))
        assertEquals("slowdown-crew", ChatAdmin.hostId("  Slowdown Crew! "))
    }

    @Test fun newMessagesPlural() {
        assertEquals("1 nová zpráva", L10nLogic.chatNewMessages(false, 1))
        assertEquals("3 nové zprávy", L10nLogic.chatNewMessages(false, 3))
        assertEquals("6 nových zpráv", L10nLogic.chatNewMessages(false, 6))
        assertEquals("6 new messages", L10nLogic.chatNewMessages(true, 6))
    }

    // Replies (1.4)

    @Test fun emojiReplyStaysOnItsOwn() {
        val original = msg(1, "2026-11-18T06:09:00Z", "Tenhle groove jede", name = "tom", user = "me")
        val r = rows(listOf(
            original,
            msg(2, "2026-11-18T06:10:00Z", "🔥", name = "nela"),
            msg(3, "2026-11-18T06:10:10Z", "🔥", name = "marty").withQuote(ChatQuote.of(original)),
            msg(4, "2026-11-18T06:10:20Z", "🔥", name = "jana"),
        ))
        assertEquals(listOf(1L, 2L, 3L, 4L), r.filterIsInstance<Row.Message>().map { it.message.id })
        assertNull(ChatTimeline.homeLines(r.filterIsInstance<Row.Message>().map { it.message }).firstOrNull { it.count > 1 })
    }

    @Test fun quoteDisplay() {
        val quote = ChatQuote(7, "karolina", "karolina.pivnivila", "supporter", "Výsadba nové chmelnice\nnení jen tak")
        assertEquals(ChatQuote.Display.Message("karolina.pivnivila", "supporter", "Výsadba nové chmelnice není jen tak"), quote.display("me"))
        assertEquals(ChatQuote.Display.Mine("Výsadba nové chmelnice není jen tak"), quote.display("karolina"))
        assertEquals(ChatQuote.Display.Unavailable, quote.display("me", hidden = setOf("karolina")))
        assertEquals(ChatQuote.Display.Unavailable, quote.copy(body = null).display("me"))
        assertEquals(ChatQuote.Display.Message(null, "listener", "Ahoj"), ChatQuote(8, null, null, "listener", "Ahoj").display("me"))
        assertEquals(true, quote.isTo("karolina"))
        assertEquals(false, quote.isTo("me"))
        assertEquals(false, quote.copy(body = null).isTo("karolina"))
    }

    @Test fun decodesReplyColumns() {
        val json = """{"id": 9, "user_id": "u9", "author_name": "marty", "author_role": "listener", "body": "Taky!",
            "created_at": "2026-11-18T06:10:00+00:00", "reply_to_id": 4, "reply_to_user_id": "u4",
            "reply_to_author": "karolina.pivnivila", "reply_to_role": "supporter", "reply_to_body": "Výsadba"}"""
        val message = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }.decodeFromString<ChatMessage>(json)
        assertEquals(ChatQuote(4, "u4", "karolina.pivnivila", "supporter", "Výsadba"), message.replyTo)
        val plain = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }
            .decodeFromString<ChatMessage>("""{"id": 1, "body": "Ahoj", "created_at": "2026-11-18T06:10:00+00:00"}""")
        assertNull(plain.replyTo)
    }
}
