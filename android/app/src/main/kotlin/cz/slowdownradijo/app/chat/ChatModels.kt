package cz.slowdownradijo.app.chat

import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.data.ScheduleStore.Companion.STATION_ZONE
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/** One row of `chat_messages` (`backend/supabase/sql/020_chat.sql`). As `ChatModels.swift`. */
@Serializable
data class ChatMessage(
    val id: Long,
    /** Null once the author deleted their account. */
    @SerialName("user_id") val userId: String? = null,
    /** The author's current name; null for a deleted account. */
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("author_role") val role: String = "listener",
    /** Null once a moderator deleted the message. */
    val body: String? = null,
    @SerialName("show_id") val showId: String? = null,
    @SerialName("show_title") val showTitle: String? = null,
    @SerialName("created_at") val createdAtText: String,
    @SerialName("deleted_at") val deletedAtText: String? = null,
    @SerialName("pinned_at") val pinnedAtText: String? = null,
) {
    val createdAt: Instant get() = parse(createdAtText) ?: Instant.EPOCH
    val pinnedAt: Instant? get() = pinnedAtText?.let(::parse)
    val isDeleted: Boolean get() = deletedAtText != null || body == null

    /** The message is a single emoji ("🔥"): those merge into "🔥 ×4". */
    val singleEmoji: String?
        get() {
            val text = body?.trim() ?: return null
            if (isDeleted || text.isEmpty()) return null
            val graphemes = java.text.BreakIterator.getCharacterInstance().run {
                setText(text)
                var count = 0
                while (next() != java.text.BreakIterator.DONE) count++
                count
            }
            return if (graphemes == 1 && isEmoji(text)) text else null
        }

    companion object {
        fun parse(text: String): Instant? = AccountService.parseIso(text.replace(' ', 'T'))
            ?: AccountService.parseIso(text)

        private fun isEmoji(text: String): Boolean {
            val first = text.codePointAt(0)
            return Character.isSupplementaryCodePoint(first) || first in 0x2600..0x27BF ||
                text.contains('️')
        }
    }
}

/** A message the listener sent that the server hasn't confirmed yet (Figma K). */
data class OutgoingChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val body: String,
    val createdAt: Instant,
    val failed: Boolean = false,
)

/** The listener's role, from `chat_me`, for their own unsent messages. */
enum class ChatRole { LISTENER, SUPPORTER, DJ, ADMIN;
    companion object {
        fun of(text: String?): ChatRole = when (text) {
            "supporter" -> SUPPORTER
            "dj" -> DJ
            "admin" -> ADMIN
            else -> LISTENER
        }
    }
}

/**
 * What the chat stream draws, as `ChatTimeline` in ChatModels.swift: a divider only
 * before the first message of a day or a show ("Dnes · 07:00 Morning Coffee", then
 * "22:00 Noční linka"), the same emoji in a row within 60 s merged ("🔥 ×4"), and
 * hidden listeners left out.
 */
object ChatTimeline {
    sealed interface Row {
        val key: String
        data class Divider(val id: String, val text: String) : Row { override val key get() = "d-$id" }
        data class Message(val message: ChatMessage) : Row { override val key get() = "m-${message.id}" }
        data class Emoji(val id: String, val emoji: String, val count: Int, val names: List<String>) : Row { override val key get() = "e-$id" }
        data class Outgoing(val message: OutgoingChatMessage) : Row { override val key get() = "o-${message.id}" }
    }

    /** Names the show in a divider: its start ("07:00") and title. */
    data class ShowLabel(val start: String?, val title: String)

    /** The words the rows need, so the logic stays free of Android resources. */
    data class Words(
        val today: String,
        val yesterday: String,
        val noShow: String,
        val deletedAccount: String,
        val english: Boolean,
    )

    const val EMOJI_MERGE_SECONDS = 60L

    fun rows(
        messages: List<ChatMessage>,
        words: Words,
        outgoing: List<OutgoingChatMessage> = emptyList(),
        outgoingShow: Pair<String?, String?> = null to null,
        hidden: Set<String> = emptySet(),
        now: Instant = Instant.now(),
        zone: ZoneId = STATION_ZONE,
        showLabel: (showId: String?, title: String?, at: Instant) -> ShowLabel?,
    ): List<Row> {
        val rows = mutableListOf<Row>()
        var lastDay: LocalDate? = null
        var lastShow: String? = null
        var started = false

        data class Group(val first: ChatMessage, var last: ChatMessage, val emoji: String, var count: Int, val names: MutableList<String>)
        var group: Group? = null

        fun flush() {
            val g = group ?: return
            rows += if (g.count == 1) Row.Message(g.first) else Row.Emoji(g.first.id.toString(), g.emoji, g.count, g.names.toList())
            group = null
        }

        fun divide(at: Instant, showId: String?, title: String?, id: String) {
            val day = at.atZone(zone).toLocalDate()
            val show = showId.orEmpty()
            if (started && lastDay == day && lastShow == show) return
            flush()
            val dayChanged = !started || lastDay != day
            started = true
            lastDay = day
            lastShow = show
            val parts = mutableListOf<String>()
            if (dayChanged) parts += dayLabel(day, now, zone, words)
            val label = showLabel(showId, title, at)
            if (label != null) parts += listOfNotNull(label.start, label.title).joinToString(" ")
            else if (showId == null) parts += words.noShow
            if (parts.isNotEmpty()) rows += Row.Divider(id, parts.joinToString(" · "))
        }

        for (message in messages) {
            if (message.userId != null && message.userId in hidden) continue
            divide(message.createdAt, message.showId, message.showTitle, message.id.toString())
            val emoji = message.singleEmoji
            if (emoji != null) {
                val g = group
                if (g != null && g.emoji == emoji &&
                    message.createdAt.epochSecond - g.last.createdAt.epochSecond <= EMOJI_MERGE_SECONDS
                ) {
                    g.last = message
                    g.count += 1
                    val name = message.authorName ?: words.deletedAccount
                    if (name !in g.names) g.names += name
                    continue
                }
                flush()
                group = Group(message, message, emoji, 1, mutableListOf(message.authorName ?: words.deletedAccount))
                continue
            }
            flush()
            rows += Row.Message(message)
        }
        flush()

        for (message in outgoing) {
            divide(message.createdAt, outgoingShow.first, outgoingShow.second, message.id)
            rows += Row.Outgoing(message)
        }
        return rows
    }

    /** A line of the home page ticker: a message, or the last of a run of the same emoji ("🔥 ×4"). */
    data class HomeLine(val message: ChatMessage, val count: Int = 1) {
        val id: Long get() = message.id
    }

    /** The home page's lines: the same emoji in a row (within 60 s) is one line. */
    fun homeLines(messages: List<ChatMessage>): List<HomeLine> {
        val out = mutableListOf<HomeLine>()
        for (m in messages) {
            val last = out.lastOrNull()
            val emoji = m.singleEmoji
            if (emoji != null && last != null && last.message.singleEmoji == emoji &&
                m.createdAt.epochSecond - last.message.createdAt.epochSecond <= EMOJI_MERGE_SECONDS
            ) {
                out[out.lastIndex] = HomeLine(m, last.count + 1)
            } else {
                out += HomeLine(m)
            }
        }
        return out
    }

    /** "Dnes", "Včera", "Po 10. 11." */
    fun dayLabel(day: LocalDate, now: Instant, zone: ZoneId, words: Words): String {
        val today = now.atZone(zone).toLocalDate()
        return when (day) {
            today -> words.today
            today.minusDays(1) -> words.yesterday
            else -> {
                val text = if (words.english) {
                    DateTimeFormatter.ofPattern("EEE d MMM", Locale.UK).format(day)
                } else {
                    DateTimeFormatter.ofPattern("EEE d. M.", Locale.forLanguageTag("cs")).format(day)
                }
                text.replaceFirstChar { it.uppercase() }
            }
        }
    }

    /** "Včera 23:41 · Noční linka": the time line in a message's menu. */
    fun timeLine(message: ChatMessage, now: Instant, zone: ZoneId, words: Words): String {
        val at = message.createdAt.atZone(zone)
        val text = dayLabel(at.toLocalDate(), now, zone, words) + " " + DateTimeFormatter.ofPattern("H:mm").format(at)
        return message.showTitle?.let { "$text · $it" } ?: text
    }
}
