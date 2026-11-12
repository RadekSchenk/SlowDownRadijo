package cz.slowdownradijo.app.widget

import android.app.Activity
import android.graphics.BitmapFactory
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.ExperimentalGlanceRemoteViewsApi
import androidx.glance.appwidget.GlanceRemoteViews
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.RemotePlayedTrack
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.SharedImages
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.Instant

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-xxhdpi")
class WidgetTest {
    private val store = ScheduleStore(ScheduleStore.parse(File("../../SlowDownRadijo/Resources/schedule.json").readText()))
    /** Monday 9 Nov 2026, 13:30 in Prague: Show podle Majkla (hosted, 13:00–14:00). */
    private val now = Instant.parse("2026-11-09T12:30:00Z")
    private fun logged(artist: String, title: String, minutesAgo: Long) =
        RemotePlayedTrack("1", artist, title, now.minusSeconds(minutesAgo * 60).toString())

    @Test fun `a fresh real song shows, and the widget looks again when it goes stale`() {
        val (entry, reload) = WidgetData.entry(store, logged("Khruangbin", "Maria También", 3), now)
        assertEquals("Show podle Majkla", entry.show?.displayTitle)
        assertEquals(NowPlayingTrack("Khruangbin", "Maria También"), entry.track)
        assertEquals(now.plusSeconds(7 * 60), reload)
    }

    @Test fun `stale songs, placeholders and songs from before the show stay out`() {
        assertNull(WidgetData.entry(store, logged("Khruangbin", "Maria También", 11), now).first.track)
        assertNull(WidgetData.entry(store, logged("SLOWDOWN", "PROMO", 1), now).first.track)
        // Started 12:58 in Prague, before Show podle Majkla began at 13:00; it's 13:03 now.
        val playedAt = Instant.parse("2026-11-09T11:58:00Z")
        assertNull(WidgetData.entry(store, RemotePlayedTrack("1", "Khruangbin", "Maria También", playedAt.toString()), Instant.parse("2026-11-09T12:03:00Z")).first.track)
    }

    @Test fun `reload at the show's end when that comes first`() {
        // 13:50 in Prague: the show ends at 14:00, sooner than 15 minutes.
        val at = Instant.parse("2026-11-09T12:50:00Z")
        assertEquals(Instant.parse("2026-11-09T13:00:00Z"), WidgetData.entry(store, null, at).second)
    }

    @OptIn(ExperimentalGlanceRemoteViewsApi::class)
    private fun capture(name: String, size: DpSize, entry: WidgetEntry) = runTest {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val photo = SharedImages.drawable(entry.show?.artworkName ?: entry.show?.hostImageName)?.let {
            BitmapFactory.decodeResource(activity.resources, it, BitmapFactory.Options().apply { inSampleSize = 4 })
        }
        val result = GlanceRemoteViews().compose(activity, size) { WidgetContent(entry, photo) }
        val density = activity.resources.displayMetrics.density
        val frame = FrameLayout(activity).apply { setBackgroundColor(0xFF2B2B2B.toInt()); setPadding(40, 40, 40, 40) }
        val view: View = result.remoteViews.apply(activity, frame)
        frame.addView(view, ViewGroup.LayoutParams((size.width.value * density).toInt(), (size.height.value * density).toInt()))
        activity.setContentView(frame)
        frame.captureRoboImage("src/test/screenshots/$name.png")
    }

    private val majkla get() = store.currentShow(now)

    @Test fun mediumWithSong() = capture("widget_medium_song", NowPlayingWidget.MEDIUM, WidgetEntry(majkla, NowPlayingTrack("Khruangbin", "Maria También")))

    @Test fun mediumHost() = capture("widget_medium_host", NowPlayingWidget.MEDIUM, WidgetEntry(majkla, null))

    @Test fun small() = capture("widget_small", NowPlayingWidget.SMALL, WidgetEntry(majkla, null))

    @Test fun mediumNoShow() = capture("widget_medium_empty", DpSize(250.dp, 110.dp), WidgetEntry(null, null))
}
