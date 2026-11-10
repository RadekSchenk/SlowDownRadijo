package cz.slowdownradijo.app.data

import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Against the real week from slowdownradijo.cz (fixtures saved 10 Nov 2026). */
class WebScheduleServiceTest {
    private val catalog = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText())).catalog
    private fun fixture(name: String) = javaClass.classLoader!!.getResource("web/$name")!!.readText()

    private fun week() = WebScheduleService.build(
        WebScheduleService.parseWeek(fixture("schedule.json")),
        WebScheduleService.parseShows(fixture("shows.json")),
        catalog,
    )

    @Test fun `the web week covers every day from midnight to midnight`() {
        val days = week()
        assertEquals((1..7).toList(), days.map { it.weekday })
        for (day in days) {
            assertEquals("00:00", day.shows.first().start)
            assertEquals("00:00", day.shows.last().end)
            day.shows.zipWithNext().forEach { (a, b) -> assertEquals(day.dayName, a.end, b.start) }
        }
    }

    @Test fun `known shows keep their bundled host and photo`() {
        val shows = week().flatMap { it.shows }
        val beatBrunch = shows.first { it.webID == 13904 }
        assertEquals("Jaro Cossiga", beatBrunch.hostName)
        assertNotNull(beatBrunch.hostImageName)
    }

    @Test fun `web titles are plain text`() {
        val web = WebScheduleService.parseShows(fixture("shows.json"))
        assertEquals("live & direct z Cannafest 2026", web.first { it.id == 16016 }.title)
        assertTrue(web.first { it.id == 16245 }.title.contains("cube positive"))
    }

    @Test fun `weekday from title, slug or order`() {
        assertEquals(2, WebScheduleService.DayPost("Pondělí", "", null, emptyList()).weekday)
        assertEquals(1, WebScheduleService.DayPost("?", "sunday-2", null, emptyList()).weekday)
        assertEquals(7, WebScheduleService.DayPost("?", "?", 6, emptyList()).weekday)
    }

    @Test fun `special ids are slugs in the stats alphabet`() {
        assertEquals("live-direct-z-cannafest-2026", WebScheduleService.showId("live-direct-z-cannafest-2026", 1))
        assertEquals("prilis-zlutoucky-kun", WebScheduleService.showId("p%C5%99%C3%ADli%C5%A1-%C5%BElu%C5%A5ou%C4%8Dk%C3%BD-k%C5%AF%C5%88", 1))
        assertEquals("web-7", WebScheduleService.showId("", 7))
    }

    @Test fun `HTML entities decode`() {
        assertEquals("Rock & Roll – live …", HtmlText.plain("<p>Rock &#038; Roll &ndash; live [&hellip;]</p>"))
        assertEquals("a b", HtmlText.plain("a&nbsp;b"))
    }

    @Test fun `fetch reads both endpoints`() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody(fixture("schedule.json")))
            server.enqueue(MockResponse().setBody(fixture("shows.json")))
            val service = WebScheduleService(OkHttpClient(), server.url("/").toString().trimEnd('/'))
            assertEquals(7, service.fetch(catalog).size)
            assertEquals("/wp-json/proradio/v1/schedule", server.takeRequest().path)
            assertTrue(server.takeRequest().path!!.startsWith("/wp-json/wp/v2/shows?include="))
        }
    }

    @Test fun `store keeps its week when the fetch fails and caches a new one`() = runTest {
        val file = File.createTempFile("schedule", ".json").apply { delete() }
        val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()), file)
        val before = store.days.value
        store.refresh({ error("offline") })
        assertEquals(before, store.days.value)
        val web = week()
        store.refresh({ web }, force = true)
        assertEquals(web, store.days.value)
        assertTrue(file.exists())
        val reopened = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()), file)
        assertEquals(web, reopened.days.value)
    }
}
