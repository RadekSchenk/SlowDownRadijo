package cz.slowdownradijo.app.account

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class AccountErrorTest {
    @Test fun `server codes map to errors`() {
        assertEquals(AccountError.NicknameTaken, AccountError.fromServerCode("nickname_taken"))
        assertEquals(AccountError.Blocked, AccountError.fromServerCode("blocked"))
        assertEquals(AccountError.AccountRequired, AccountError.fromServerCode("account_required"))
        assertTrue(AccountError.fromServerCode("something_new") is AccountError.Unknown)
    }

    @Test fun `mute and cooldown carry the time from the detail`() {
        val muted = AccountError.fromServerCode("muted", "2026-11-18 08:04:12.345678+00") as AccountError.Muted
        assertEquals(Instant.parse("2026-11-18T08:04:12.345678Z"), muted.until)
        val cooldown = AccountError.fromServerCode("nickname_cooldown", "2026-11-18 08:04:12+00") as AccountError.NicknameCooldown
        assertEquals(Instant.parse("2026-11-18T08:04:12Z"), cooldown.until)
    }

    @Test fun `chat_me dates parse`() {
        val me = AccountService.Me(userId = "u", mutedUntilText = "2026-11-18T08:04:12.345678+00:00")
        assertNotNull(me.mutedUntil)
    }

    @Test fun `nonce hash is the sha256 of the raw value`() {
        val (raw, hashed) = AccountService.makeNonce()
        assertEquals(64, raw.length)
        assertEquals(64, hashed.length)
        assertTrue(raw != hashed)
    }
}
