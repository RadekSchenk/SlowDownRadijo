package cz.slowdownradijo.app.player

import cz.slowdownradijo.app.data.NowPlayingTrack
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IcyMetadataPollerTest {
    private fun icyBody(metaInt: Int, title: String?, charset: java.nio.charset.Charset = Charsets.UTF_8): Buffer {
        val buffer = Buffer().write(ByteArray(metaInt) { 0x55 })
        if (title == null) return buffer.writeByte(0)
        val meta = "StreamTitle='$title';".toByteArray(charset)
        val blocks = (meta.size + 15) / 16
        return buffer.writeByte(blocks).write(meta).write(ByteArray(blocks * 16 - meta.size)).write(ByteArray(500))
    }

    private suspend fun poll(response: MockResponse): NowPlayingTrack? = MockWebServer().use { server ->
        server.enqueue(response)
        val result = IcyMetadataPoller(OkHttpClient(), server.url("/slowdown.aac").toString()).pollOnce()
        assertEquals("1", server.takeRequest().getHeader("Icy-MetaData"))
        result
    }

    @Test fun `reads the title after icy-metaint bytes`() = runTest {
        val track = poll(MockResponse().setHeader("icy-metaint", "16000").setBody(icyBody(16000, "SLOWDOWN - Nils Frahm - Says")))
        assertEquals(NowPlayingTrack("Nils Frahm", "Says"), track)
    }

    @Test fun `Latin-1 titles decode`() = runTest {
        val track = poll(MockResponse().setHeader("icy-metaint", "100").setBody(icyBody(100, "Beyoncé - Halo", Charsets.ISO_8859_1)))
        assertEquals(NowPlayingTrack("Beyoncé", "Halo"), track)
    }

    @Test fun `no metadata this cycle, or no icy support`() = runTest {
        assertNull(poll(MockResponse().setHeader("icy-metaint", "64").setBody(icyBody(64, null))))
        assertNull(poll(MockResponse().setBody("plain")))
    }

    @Test fun `reconnect back-off`() {
        assertEquals(listOf(2000L, 4000L, 8000L, 16000L, 30000L, 30000L), (1..6).map(ReconnectPolicy::delayMillis))
    }
}
