package cz.slowdownradijo.app.news

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import cz.slowdownradijo.app.MainActivity
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.HtmlText
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.inLanguage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset

/** A post from slowdownradijo.cz (`NewsPost.swift`). */
data class NewsPost(val id: Int, val dateGmt: Instant, val title: String, val contentHtml: String, val imageUrl: String?) {
    val blocks: List<NewsBlock> get() = NewsContentParser.parse(contentHtml)
}

sealed interface NewsBlock {
    data class Paragraph(val text: String) : NewsBlock
    data class Image(val url: String) : NewsBlock
    data class Video(val url: String) : NewsBlock
}

/** Paragraphs, images and embedded videos from a post's HTML, as `NewsContentParser.swift`. */
object NewsContentParser {
    private val media = Regex("""<img[^>]+src="([^"]+)"[^>]*>|<iframe[^>]+src="([^"]+)"[^>]*>.*?</iframe>""", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))

    fun parse(html: String): List<NewsBlock> {
        val blocks = mutableListOf<NewsBlock>()
        var cursor = 0
        for (match in media.findAll(html)) {
            paragraphs(html.substring(cursor, match.range.first), blocks)
            val image = match.groups[1]?.value
            val video = match.groups[2]?.value
            when {
                !image.isNullOrEmpty() -> blocks += NewsBlock.Image(HtmlText.decodeEntities(image))
                !video.isNullOrEmpty() -> blocks += NewsBlock.Video(HtmlText.decodeEntities(video))
            }
            cursor = match.range.last + 1
        }
        paragraphs(html.substring(cursor), blocks)
        return blocks
    }

    private fun paragraphs(raw: String, into: MutableList<NewsBlock>) {
        val normalized = raw.replace(Regex("</p>", RegexOption.IGNORE_CASE), "\n\n")
            .replace(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE), "\n")
        for (chunk in normalized.split("\n\n")) {
            // Line breaks inside a paragraph stay; tags and entities go.
            val text = chunk.split("\n").joinToString("\n") { HtmlText.plain(it) }.trim()
            if (text.isNotEmpty()) into += NewsBlock.Paragraph(text)
        }
    }
}

/** `/wp/v2/posts`, newest first (`NewsService.swift`). */
class NewsService(private val client: OkHttpClient, private val baseUrl: String = "https://slowdownradijo.cz") {
    suspend fun fetchRecent(limit: Int = 30): List<NewsPost> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/wp-json/wp/v2/posts".toHttpUrl().newBuilder()
            .addQueryParameter("_embed", "true")
            .addQueryParameter("per_page", "$limit")
            .addQueryParameter("orderby", "date")
            .addQueryParameter("order", "desc")
            .build()
        client.newCall(Request.Builder().url(url).build()).execute().use {
            if (!it.isSuccessful) throw IOException("posts: ${it.code}")
            parse(it.body.string())
        }
    }

    companion object {
        fun parse(text: String): List<NewsPost> =
            cz.slowdownradijo.app.data.ScheduleStore.json.parseToJsonElement(text).jsonArray.mapNotNull { element ->
                val post = element as? JsonObject ?: return@mapNotNull null
                fun rendered(key: String) = ((post[key] as? JsonObject)?.get("rendered") as? JsonPrimitive)?.content
                val media = ((post["_embedded"] as? JsonObject)?.get("wp:featuredmedia") as? JsonArray)?.firstOrNull() as? JsonObject
                NewsPost(
                    id = (post["id"] as? JsonPrimitive)?.intOrNull ?: return@mapNotNull null,
                    dateGmt = (post["date_gmt"] as? JsonPrimitive)?.content
                        ?.let { runCatching { LocalDateTime.parse(it).toInstant(ZoneOffset.UTC) }.getOrNull() } ?: Instant.EPOCH,
                    title = HtmlText.plain(rendered("title") ?: ""),
                    contentHtml = rendered("content") ?: "",
                    imageUrl = (media?.get("source_url") as? JsonPrimitive)?.content,
                )
            }
    }
}

/** The news list's state, and "Nová novinka" at launch (`NewsViewModel`, `NewsNotificationManager.swift`). */
class NewsStore(private val context: Context, private val service: NewsService) {
    sealed interface State {
        data object Loading : State
        data object Failed : State
        data class Loaded(val posts: List<NewsPost>) : State
    }

    private val prefs = context.getSharedPreferences("news", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow<State>(State.Loading)
    val state: StateFlow<State> = _state.asStateFlow()
    private val _notificationsEnabled = MutableStateFlow(prefs.getBoolean(ENABLED, true))
    val notificationsEnabled: StateFlow<Boolean> = _notificationsEnabled.asStateFlow()

    fun setNotificationsEnabled(on: Boolean) {
        prefs.edit().putBoolean(ENABLED, on).apply()
        _notificationsEnabled.value = on
    }

    fun post(id: Int): NewsPost? = (_state.value as? State.Loaded)?.posts?.firstOrNull { it.id == id }

    suspend fun loadIfNeeded() {
        if (_state.value is State.Loaded) return
        refresh()
    }

    suspend fun refresh() {
        _state.value = runCatching { State.Loaded(service.fetchRecent()) }.getOrElse { State.Failed }
    }

    /**
     * At launch: a post newer than the last one seen is announced, if the
     * listener allowed notifications. The first run only notes the latest.
     */
    suspend fun checkForNewPost(language: AppLanguage, notificationsAllowed: Boolean) {
        if (!_notificationsEnabled.value) return
        val latest = runCatching { service.fetchRecent(limit = 1) }.getOrNull()?.firstOrNull() ?: return
        if (!prefs.contains(LAST_SEEN)) {
            prefs.edit().putInt(LAST_SEEN, latest.id).apply()
            return
        }
        if (prefs.getInt(LAST_SEEN, 0) == latest.id) return
        prefs.edit().putInt(LAST_SEEN, latest.id).apply()
        if (!notificationsAllowed) return

        val res = context.inLanguage(language)
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, res.getString(R.string.newsTitle), NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(
            context, latest.id, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        runCatching {
            manager.notify(
                "news".hashCode() + latest.id,
                NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(R.drawable.tab_icon_message)
                    .setContentTitle(res.getString(R.string.newsNotificationTitle))
                    .setContentText(latest.title)
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    .build(),
            )
        }
    }

    companion object {
        private const val ENABLED = "newsNotificationsEnabled"
        private const val LAST_SEEN = "news.lastSeenPostID"
        const val CHANNEL = "news"
    }
}
