package cz.slowdownradijo.app.stats

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import cz.slowdownradijo.app.data.ScheduleStore
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@RunWith(AndroidJUnit4::class)
class StatsTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val zone = ZoneId.of("Europe/Prague")
    private var clock = Instant.parse("2026-11-10T10:00:00Z")

    private class FakeApi : StatsApi {
        val batches = mutableListOf<Pair<String, List<ListeningRow>>>()
        var fail = false
        var snapshot: StatsSnapshot? = null
        override suspend fun recordListening(batchId: String, rows: List<ListeningRow>, appVersion: String) {
            if (fail) throw StatsApi.Failure.Transport()
            batches += batchId to rows.map { it.copy() }
        }
        override suspend fun fetchMyStats() = snapshot
        override suspend fun fetchPublicStats() = PublicStats(available = true, communitySeconds = 1000, rankedListeners = 12)
        override suspend fun deleteMyData() {}
    }

    private fun TestScope.tracker(api: StatsApi, enabled: () -> Boolean = { true }, show: String? = "beat-brunch") = ListeningTracker(
        api, context.getSharedPreferences("t${System.nanoTime()}", Context.MODE_PRIVATE), backgroundScope,
        isEnabled = enabled, showProvider = { show }, appVersion = "test", zone = { zone }, now = { clock }, tickMillis = 10_000,
    )

    @Test fun `seconds accrue per day and show while playing`() = runTest {
        val tracker = tracker(FakeApi())
        tracker.update(isPlaying = true)
        clock = clock.plusSeconds(25)
        tracker.accrue()
        // At most 30 s per tick, whatever the gap.
        clock = clock.plusSeconds(120)
        tracker.accrue()
        assertEquals(listOf(ListeningRow("2026-11-10", "beat-brunch", 55)), tracker.unsyncedRows)
    }

    @Test fun `stopping uploads what built up, under one batch id until confirmed`() = runTest {
        val api = FakeApi().apply { fail = true }
        val tracker = tracker(api)
        tracker.update(isPlaying = true)
        clock = clock.plusSeconds(20)
        tracker.update(isPlaying = false)
        runCurrent()
        assertTrue(tracker.hasUnconfirmedBatch)
        api.fail = false
        clock = clock.plusSeconds(31)
        tracker.retryUnconfirmedBatch()
        runCurrent()
        assertEquals(1, api.batches.size)
        assertEquals(20, api.batches[0].second.sumOf { it.seconds })
        assertEquals(emptyList<ListeningRow>(), tracker.unsyncedRows)
    }

    @Test fun `stats off drops the unsent and stops counting`() = runTest {
        var enabled = true
        val tracker = tracker(FakeApi(), enabled = { enabled })
        tracker.update(isPlaying = true)
        clock = clock.plusSeconds(8)
        tracker.accrue()
        enabled = false
        tracker.enabledPreferenceChanged()
        assertEquals(emptyList<ListeningRow>(), tracker.unsyncedRows)
        assertEquals(false, tracker.measuring.value)
    }

    @Test fun `summary adds the unsent to the server's numbers`() = runTest {
        val api = FakeApi().apply {
            snapshot = StatsSnapshot(
                available = true, totalSeconds = 7200, communitySeconds = 90_000, rankedListeners = 12, rank = 3,
                daily = listOf(StatsSnapshot.Row("2026-11-09", "bass-time", 3600), StatsSnapshot.Row("2026-11-10", "beat-brunch", 600)),
                shows = listOf(StatsSnapshot.ShowTotal("bass-time", 6600), StatsSnapshot.ShowTotal("beat-brunch", 600)),
            )
        }
        val tracker = tracker(api)
        val schedule = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
        val store = ListeningStatsStore(api, tracker, schedule, context.getSharedPreferences("s${System.nanoTime()}", Context.MODE_PRIVATE), backgroundScope, { true }, { zone }, { clock })
        store.refreshAll(force = true)
        tracker.update(isPlaying = true)
        clock = clock.plusSeconds(30)
        tracker.accrue()

        val summary = store.summary()
        assertEquals(630, summary.todaySeconds)
        assertEquals(7230, summary.totalSeconds)
        assertEquals(3, summary.rank)
        assertEquals(7, summary.bars.size)
        assertEquals("2026-11-09", summary.bars.single { it.isPeak }.day)
        assertEquals("Bass Time", summary.shows.first().name)
        assertEquals(LocalDate.parse("2026-11-04"), summary.weekStart)
        assertTrue(store.communityUnlocked)
    }

    @Test fun `formatting`() {
        assertEquals("1 h 05 m", StatsFormat.duration(false, 3900))
        assertEquals("12 m", StatsFormat.duration(false, 720))
        assertEquals("2 d 3 h 00 m", StatsFormat.duration(false, 2 * 86400 + 3 * 3600))
        assertEquals("1,5 h", StatsFormat.compactDuration(false, 5400))
        assertEquals("1.5 h", StatsFormat.compactDuration(true, 5400))
        assertEquals("4. 11. – 10. 11.", StatsFormat.dateRange(false, LocalDate.parse("2026-11-04"), LocalDate.parse("2026-11-10")))
        assertEquals("12 %", StatsFormat.percent(0.123))
    }

    @Test fun `supabase signs up once and records with the session`() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody("""{"access_token":"a1","refresh_token":"r1","expires_in":3600}"""))
            server.enqueue(MockResponse().setBody(""))
            server.enqueue(MockResponse().setBody("""{"available":false,"total_seconds":60}"""))
            val prefs = context.getSharedPreferences("api${System.nanoTime()}", Context.MODE_PRIVATE)
            val api = SupabaseStatsApi(OkHttpClient(), prefs, server.url("/").toString().trimEnd('/'))
            api.recordListening("b1", listOf(ListeningRow("2026-11-10", "x", 60)), "test")
            assertEquals("/auth/v1/signup", server.takeRequest().path)
            val record = server.takeRequest()
            assertEquals("/rest/v1/rpc/record_listening", record.path)
            assertEquals("Bearer a1", record.getHeader("Authorization"))
            assertTrue(record.body.readUtf8().contains("\"p_batch_id\":\"b1\""))
            assertEquals(60, api.fetchMyStats()!!.totalSeconds)
            assertEquals("/rest/v1/rpc/get_my_stats", server.takeRequest().path)
        }
    }

    @Test fun `no session means no stats to fetch and nothing to delete`() = runTest {
        val api = SupabaseStatsApi(OkHttpClient(), context.getSharedPreferences("e${System.nanoTime()}", Context.MODE_PRIVATE), "http://127.0.0.1:9")
        assertNull(api.fetchMyStats())
        api.deleteMyData()
    }
}
