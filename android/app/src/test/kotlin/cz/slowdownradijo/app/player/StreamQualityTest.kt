package cz.slowdownradijo.app.player

import org.junit.Assert.assertEquals
import org.junit.Test

class StreamQualityTest {
    @Test fun autoFollowsTheNetwork() {
        assertEquals(LiveStream.MP3, StreamQuality.AUTO.stream(metered = false))
        assertEquals(LiveStream.AAC, StreamQuality.AUTO.stream(metered = true))
    }

    @Test fun fixedChoicesIgnoreTheNetwork() {
        for (metered in listOf(false, true)) {
            assertEquals(LiveStream.MP3, StreamQuality.HIGH.stream(metered))
            assertEquals(LiveStream.AAC, StreamQuality.LOW.stream(metered))
        }
    }

    @Test fun storedValuesMatchIos() {
        assertEquals(StreamQuality.AUTO, StreamQuality.fromId(null))
        assertEquals(StreamQuality.AUTO, StreamQuality.fromId("nonsense"))
        assertEquals(StreamQuality.HIGH, StreamQuality.fromId("high"))
        assertEquals(StreamQuality.LOW, StreamQuality.fromId("low"))
    }

    @Test fun bothStreamsAreHttps() {
        for (stream in LiveStream.entries) assert(stream.url.startsWith("https://"))
        assertEquals(LiveStream.AAC, LiveStream.MP3.other)
    }
}
