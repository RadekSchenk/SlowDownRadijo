package cz.slowdownradijo.app.analytics

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import cz.slowdownradijo.app.player.PlaybackState
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant

@RunWith(AndroidJUnit4::class)
class AnalyticsTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    private class Recorder : AnalyticsSink {
        val sent = mutableListOf<Pair<String, List<String>>>()
        override suspend fun send(distinctId: String, events: List<Pair<AnalyticsEvent, Instant>>, properties: Map<String, Any>) {
            sent += distinctId to events.map { it.first.name }
        }
    }

    private fun fresh() = context.getSharedPreferences("analytics", Context.MODE_PRIVATE).edit().clear().commit()

    @Test fun `nothing is sent without consent, and the question comes from the third launch`() = runTest {
        fresh()
        val sink = Recorder()
        val analytics = Analytics(context, sink, backgroundScope, { "cs" })
        analytics.start()
        analytics.track(AnalyticsEvent.LinkOpened("whatsapp"))
        analytics.flushNow()
        assertTrue(sink.sent.isEmpty())
        assertFalse(analytics.shouldAskForConsent)
        analytics.start(); analytics.start()
        assertTrue(analytics.shouldAskForConsent)
    }

    @Test fun `consent sends, saying no forgets the id`() = runTest {
        fresh()
        val sink = Recorder()
        val analytics = Analytics(context, sink, backgroundScope, { "en" })
        analytics.setConsent(true)
        analytics.track(AnalyticsEvent.SleepTimerSet("15m"))
        analytics.flushNow()
        assertEquals(listOf("app_opened", "sleep_timer_set"), sink.sent.single().second)
        val firstId = sink.sent.single().first
        analytics.setConsent(false)
        analytics.setConsent(true)
        analytics.flushNow()
        assertTrue(sink.sent.last().first != firstId)
    }

    @Test fun `posthog batch carries the iOS event names and no person profile`() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse())
            PostHogSink(OkHttpClient(), server.url("").toString().trimEnd('/'))
                .send("id-1", listOf(AnalyticsEvent.MessageSent(true, 38) to Instant.parse("2026-11-10T10:00:00Z")), mapOf("platform" to "android"))
            val request = server.takeRequest()
            assertEquals("/batch/", request.path)
            val body = Json.parseToJsonElement(request.body.readUtf8()).jsonObject
            val event = body["batch"]!!.jsonArray[0].jsonObject
            assertEquals("message_sent", event["event"]!!.jsonPrimitive.content)
            val props = event["properties"]!!.jsonObject
            assertEquals("40", props["duration_s"]!!.jsonPrimitive.content)
            assertEquals("false", props["\$process_person_profile"]!!.jsonPrimitive.content)
            assertEquals("android", props["platform"]!!.jsonPrimitive.content)
        }
    }

    @Test fun `rounding as on iOS`() {
        assertEquals(20, AnalyticsEvent.rounded(17))
        assertEquals(35, AnalyticsEvent.rounded(37, 5))
        assertEquals(0, AnalyticsEvent.rounded(-3))
    }

    @Test fun `listening is credited for the review prompt on stops and each minute`() = runTest {
        fresh()
        var clock = 0L
        val credited = mutableListOf<Long>()
        val engine = cz.slowdownradijo.app.player.RadioEngine(context, backgroundScope)
        val playback = PlaybackAnalytics(engine, Analytics(context, Recorder(), backgroundScope, { "cs" }),
            context.getSharedPreferences("analytics", Context.MODE_PRIVATE), { null }, { "speaker" },
            now = { clock }, onListened = { credited += it })
        playback.handle(PlaybackState.Connecting)
        clock = 5_000; playback.handle(PlaybackState.Playing)
        clock = 65_000; playback.save()
        clock = 95_000; playback.handle(PlaybackState.Paused)
        clock = 200_000; playback.save()
        assertEquals(listOf(60L, 30L), credited)
    }
}
