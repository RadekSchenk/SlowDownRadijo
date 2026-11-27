package cz.slowdownradijo.app.chat

import cz.slowdownradijo.app.chat.ChatMenuAction.BLOCK
import cz.slowdownradijo.app.chat.ChatMenuAction.COPY
import cz.slowdownradijo.app.chat.ChatMenuAction.DELETE
import cz.slowdownradijo.app.chat.ChatMenuAction.HIDE
import cz.slowdownradijo.app.chat.ChatMenuAction.MUTE
import cz.slowdownradijo.app.chat.ChatMenuAction.PIN
import cz.slowdownradijo.app.chat.ChatMenuAction.REPLY
import cz.slowdownradijo.app.chat.ChatMenuAction.REPORT
import cz.slowdownradijo.app.chat.ChatMenuAction.UNMUTE
import cz.slowdownradijo.app.chat.ChatMenuAction.UNPIN
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

class ChatModerationTest {
    private fun msg(user: String? = "author", role: String = "listener", deleted: Boolean = false) =
        ChatMessage(1, user, "brancikovac", role, if (deleted) null else "Ahoj", createdAtText = "2026-11-18T06:00:00Z",
            deletedAtText = if (deleted) "2026-11-18T06:10:00Z" else null)

    private val muted = ChatService.UserStatus(mutedUntilText = Instant.now().plusSeconds(3600).toString(), mutedBy = "DJ Pufaz")

    @Test fun listenerOnSomeoneElse() =
        assertEquals(listOf(COPY, REPORT, HIDE), ChatMenu.actions(msg(), viewer = "me", isModerator = false, isPinned = false, status = null))

    @Test fun signedOutCanCopyAndReport() =
        assertEquals(listOf(COPY, REPORT), ChatMenu.actions(msg(), viewer = null, isModerator = false, isPinned = false, status = null))

    @Test fun ownMessageOnlyCopies() =
        assertEquals(listOf(COPY), ChatMenu.actions(msg(user = "me"), viewer = "me", isModerator = false, isPinned = false, status = null))

    @Test fun moderatorOnListener() =
        assertEquals(listOf(PIN, COPY, DELETE, MUTE, BLOCK), ChatMenu.actions(msg(), viewer = "dj", isModerator = true, isPinned = false, status = null))

    @Test fun moderatorOnMutedListener() =
        assertEquals(listOf(UNPIN, COPY, DELETE, UNMUTE, BLOCK), ChatMenu.actions(msg(), viewer = "dj", isModerator = true, isPinned = true, status = muted))

    @Test fun moderatorOnBlockedListenerCantUnblock() =
        assertEquals(listOf(PIN, COPY, DELETE), ChatMenu.actions(msg(), viewer = "dj", isModerator = true, isPinned = false, status = ChatService.UserStatus(blocked = true)))

    @Test fun moderatorCantMuteAnotherHostOrThemselves() {
        assertEquals(listOf(PIN, COPY, DELETE), ChatMenu.actions(msg(role = "dj"), viewer = "dj", isModerator = true, isPinned = false, status = null))
        assertEquals(listOf(PIN, COPY, DELETE), ChatMenu.actions(msg(user = "dj"), viewer = "dj", isModerator = true, isPinned = false, status = null))
    }

    @Test fun deletedAccountCantBeMutedOrHidden() {
        assertEquals(listOf(PIN, COPY, DELETE), ChatMenu.actions(msg(user = null), viewer = "dj", isModerator = true, isPinned = false, status = null))
        assertEquals(listOf(COPY, REPORT), ChatMenu.actions(msg(user = null), viewer = "me", isModerator = false, isPinned = false, status = null))
    }

    @Test fun replyComesFirstForWhoeverCanWrite() {
        assertEquals(listOf(REPLY, COPY, REPORT, HIDE), ChatMenu.actions(msg(), viewer = "me", isModerator = false, isPinned = false, status = null, canReply = true))
        assertEquals(listOf(REPLY, PIN, COPY, DELETE, MUTE, BLOCK), ChatMenu.actions(msg(), viewer = "dj", isModerator = true, isPinned = false, status = null, canReply = true))
        assertEquals(listOf(REPLY, COPY), ChatMenu.actions(msg(user = "me"), viewer = "me", isModerator = false, isPinned = false, status = null, canReply = true))
        assertEquals(emptyList<ChatMenuAction>(), ChatMenu.actions(msg(deleted = true), viewer = "me", isModerator = false, isPinned = false, status = null, canReply = true))
    }

    @Test fun deletedMessageHasNoActions() =
        assertEquals(emptyList<ChatMenuAction>(), ChatMenu.actions(msg(deleted = true), viewer = "dj", isModerator = true, isPinned = false, status = null))

    @Test fun inviteLinks() {
        assertEquals("a1b2c3d4e5f6", ChatService.inviteCode("https://slowdownradijo.cz/dj/a1b2c3d4e5f6"))
        assertEquals("a1b2c3d4e5f6", ChatService.inviteCode("https://www.slowdownradijo.cz/dj/A1B2C3D4E5F6/"))
        assertEquals("a1b2c3d4e5f6", ChatService.inviteCode("slowdownradijo://dj/a1b2c3d4e5f6"))
        assertNull(ChatService.inviteCode("https://slowdownradijo.cz/program/"))
        assertNull(ChatService.inviteCode("https://example.com/dj/a1b2c3d4e5f6"))
        assertNull(ChatService.inviteCode("slowdownradijo://auth?code=abc"))
        assertNull(ChatService.inviteCode("https://slowdownradijo.cz/dj/<script>"))
        assertNull(ChatService.inviteCode(null))
    }
}
