package cz.slowdownradijo.app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import cz.slowdownradijo.app.MainActivity
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.RemoteHistoryService
import cz.slowdownradijo.app.data.SharedImages
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.data.WebScheduleService
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * "Právě hraje" on the home screen, as the iOS widget
 * (`SlowDownRadijoWidget/`): ON AIR, the show on air, and the song while
 * it is certainly playing; with room for it, the show's photo. A tap opens
 * the app. Glance draws with the system font: home screen widgets can't
 * use the app's Manrope.
 */
class NowPlayingWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val app = context.app
        // The week as the web has it; the last one fetched, or the bundled one, if that fails.
        runCatching { app.schedule.refresh(WebScheduleService(app.http)::fetch) }
        val latest = runCatching {
            RemoteHistoryService(app.http).fetchPage(before = null, windowStart = Instant.now().minus(Duration.ofHours(3)), limit = 1).firstOrNull()
        }.getOrNull()
        val (entry, reload) = WidgetData.entry(app.schedule, latest, Instant.now())
        WidgetUpdates.scheduleNext(context, reload)
        val photo = photo(context, entry.show)
        provideContent { WidgetContent(entry, photo) }
    }

    /** The show's photo, scaled down: a widget's bitmaps must stay small. */
    private fun photo(context: Context, show: Show?): Bitmap? {
        val id = SharedImages.drawable(show?.artworkName ?: show?.hostImageName) ?: return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeResource(context.resources, id, bounds)
        val sample = Integer.highestOneBit(maxOf(1, minOf(bounds.outWidth, bounds.outHeight) / 180))
        return BitmapFactory.decodeResource(context.resources, id, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
    }
}

private val onAirRed = Color(0xFFD91F1F)
private const val STATION = "Slow Down Rádijo"

@Composable
fun WidgetContent(entry: WidgetEntry, photo: Bitmap?) {
    val medium = LocalSize.current.width >= NowPlayingWidget.MEDIUM.width
    val description = listOfNotNull(entry.show?.name ?: STATION, entry.track?.let { "${it.title} · ${it.artist}" } ?: entry.show?.hostName).joinToString(", ")
    Box(
        GlanceModifier
            .fillMaxSize()
            .background(Theme.background)
            .cornerRadius(20.dp)
            .clickable(actionStartActivity<MainActivity>())
            .semantics { contentDescription = description }
            .padding(16.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        if (medium) Medium(entry, photo) else Small(entry)
    }
}

@Composable
private fun Small(entry: WidgetEntry) {
    Column(GlanceModifier.fillMaxSize()) {
        OnAirBadge()
        Spacer(GlanceModifier.defaultWeight())
        Text(entry.show?.name ?: STATION, style = text(15, Theme.textPrimary, FontWeight.Bold), maxLines = 2)
        entry.show?.hostName?.let { Text(it.uppercase(), style = text(10, Theme.gold, FontWeight.Medium), maxLines = 1) }
    }
}

@Composable
private fun Medium(entry: WidgetEntry, photo: Bitmap?) {
    Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        if (photo != null) {
            Image(ImageProvider(photo), contentDescription = null, contentScale = ContentScale.Crop, modifier = GlanceModifier.size(60.dp).cornerRadius(16.dp))
        } else {
            Image(ImageProvider(R.drawable.brand_logo), contentDescription = null, contentScale = ContentScale.Fit, modifier = GlanceModifier.width(60.dp).height(46.dp))
        }
        Spacer(GlanceModifier.width(14.dp))
        Column {
            OnAirBadge()
            Spacer(GlanceModifier.height(6.dp))
            Text(entry.show?.name ?: STATION, style = text(17, Theme.textPrimary, FontWeight.Bold), maxLines = 1)
            Spacer(GlanceModifier.height(6.dp))
            val track: NowPlayingTrack? = entry.track
            when {
                track != null -> Text("${track.title} · ${track.artist}", style = text(12, Theme.lavender, FontWeight.Medium), maxLines = 1)
                entry.show?.hostName != null -> Text(entry.show.hostName.uppercase(), style = text(11, Theme.gold, FontWeight.Medium), maxLines = 1)
            }
        }
    }
}

@Composable
private fun OnAirBadge() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(GlanceModifier.size(7.dp).cornerRadius(4.dp).background(onAirRed)) {}
        Spacer(GlanceModifier.width(5.dp))
        Text("ON AIR", style = text(10, onAirRed, FontWeight.Bold))
    }
}

private fun text(size: Int, color: Color, weight: FontWeight) = TextStyle(color = ColorProvider(color), fontSize = size.sp, fontWeight = weight)

class NowPlayingWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NowPlayingWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdates.ensurePeriodic(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUpdates.cancel(context)
    }
}

/** Refreshes the widget every 15 minutes and at the next change (show end, song gone stale). */
object WidgetUpdates {
    private const val PERIODIC = "widget-periodic"
    private const val NEXT = "widget-next"

    fun ensurePeriodic(context: Context) {
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<UpdateWorker>(15, TimeUnit.MINUTES).build(),
        )
    }

    fun scheduleNext(context: Context, at: Instant) {
        val delay = maxOf(0L, Duration.between(Instant.now(), at).toMillis())
        WorkManager.getInstance(context).enqueueUniqueWork(
            NEXT, ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<UpdateWorker>().setInitialDelay(delay, TimeUnit.MILLISECONDS).build(),
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(PERIODIC)
        WorkManager.getInstance(context).cancelUniqueWork(NEXT)
    }

    /** Only when a widget is on the home screen. */
    suspend fun updateIfPlaced(context: Context) {
        if (GlanceAppWidgetManager(context).getGlanceIds(NowPlayingWidget::class.java).isNotEmpty()) NowPlayingWidget().updateAll(context)
    }

    class UpdateWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
        override suspend fun doWork(): Result {
            updateIfPlaced(applicationContext)
            return Result.success()
        }
    }
}
