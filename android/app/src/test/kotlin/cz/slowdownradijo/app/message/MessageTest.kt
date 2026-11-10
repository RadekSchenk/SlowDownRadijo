package cz.slowdownradijo.app.message

import cz.slowdownradijo.app.feedback.DeviceInfo
import cz.slowdownradijo.app.feedback.FeedbackForm
import cz.slowdownradijo.app.feedback.FeedbackService
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class MessageTest {
    @Test fun `levels map decibels like iOS`() {
        assertEquals(0f, VoiceMessage.normalizedLevel(0))
        assertEquals(1f, VoiceMessage.normalizedLevel(32767), 0.001f)
        assertEquals(0.4f, VoiceMessage.normalizedLevel(1036), 0.01f) // -30 dB
        assertEquals("00:38", formatted(38.9))
    }

    @Test fun `voice message goes as multipart audio`() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse())
            val file = File.createTempFile("vzkaz", ".m4a").apply { writeBytes(byteArrayOf(0, 0, 0, 24) + "ftypM4A ".toByteArray()) }
            VoiceMessageUploader(OkHttpClient(), server.url("/send-voice-message").toString()).upload(file)
            val body = server.takeRequest().body.readUtf8()
            assertTrue(body.contains("name=\"audio\""))
            assertTrue(body.contains("Content-Type: audio/m4a"))
            assertTrue(body.contains("ftypM4A"))
        }
    }

    @Test fun `feedback sends the message with the device`() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse())
            server.enqueue(MockResponse().setResponseCode(500))
            val results = mutableListOf<Boolean>()
            val form = FeedbackForm(FeedbackService(OkHttpClient(), server.url("/send-feedback").toString())) { results += it }
            form.edit("  Super appka  ")
            val device = DeviceInfo("1.1", "1", "Android 17", "Google Pixel 9", "CS")
            form.submit(device)
            assertEquals(FeedbackForm.State.SENT, form.state.value)
            val body = server.takeRequest().body.readUtf8()
            assertTrue(body.contains("\"message\":\"Super appka\""))
            assertTrue(body.contains("\"osVersion\":\"Android 17\""))
            form.reset()
            form.edit("Ještě jednou")
            form.submit(device)
            assertEquals(FeedbackForm.State.FAILED, form.state.value)
            assertEquals(listOf(true, false), results)
            form.edit("ab")
            assertEquals(false, form.canSubmit)
        }
    }
}
