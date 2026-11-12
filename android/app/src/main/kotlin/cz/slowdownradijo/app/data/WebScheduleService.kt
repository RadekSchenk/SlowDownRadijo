package cz.slowdownradijo.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.net.URLDecoder
import java.text.Normalizer

/**
 * The week as slowdownradijo.cz shows it, as `WebScheduleService.swift`:
 * the week (`/proradio/v1/schedule`) and its shows (`/wp/v2/shows`). A show
 * the app knows (by `webID` or name) keeps everything bundled for it with
 * the web's times; a special gets its title and photo from the web. Hours
 * the web leaves empty are the rotation, "The Best of Slow Down".
 */
class WebScheduleService(
    private val client: OkHttpClient,
    private val baseUrl: String = "https://slowdownradijo.cz",
) {
    class Incomplete(message: String) : IOException(message)

    suspend fun fetch(catalog: List<Show>): List<ScheduleDay> = withContext(Dispatchers.IO) {
        val week = parseWeek(get("$baseUrl/wp-json/proradio/v1/schedule"))
        val ids = week.flatMap { day -> day.slots.flatMap { it.showIds } }.toSortedSet()
        val shows = if (ids.isEmpty()) emptyList() else parseShows(get(showsUrl(ids)))
        build(week, shows, catalog)
    }

    fun showsUrl(ids: Collection<Int>): String =
        "$baseUrl/wp-json/wp/v2/shows".toHttpUrl().newBuilder()
            .addQueryParameter("include", ids.sorted().joinToString(","))
            .addQueryParameter("per_page", "100")
            .addQueryParameter("_embed", "wp:featuredmedia")
            .addQueryParameter("_fields", "id,slug,title,excerpt,_links,_embedded")
            .build().toString()

    private fun get(url: String): String {
        val request = Request.Builder().url(url).header("Cache-Control", "no-cache").build()
        return client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IOException("$url: ${response.code}")
            response.body.string()
        }
    }

    data class DayPost(val title: String, val slug: String, val order: Int?, val slots: List<Slot>) {
        /** Sunday-first weekday: from the Czech title, the English slug, or the order (1 = Monday). */
        val weekday: Int?
            get() {
                val czech = mapOf("nedele" to 1, "pondeli" to 2, "utery" to 3, "streda" to 4, "ctvrtek" to 5, "patek" to 6, "sobota" to 7)
                czech[normalized(title)]?.let { return it }
                val english = listOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
                english.indexOfFirst { slug.lowercase().startsWith(it) }.takeIf { it >= 0 }?.let { return it + 1 }
                return order?.takeIf { it in 1..7 }?.let { it % 7 + 1 }
            }
    }

    data class Slot(val showIds: List<Int>, val start: String, val end: String)

    data class WebShow(val id: Int, val slug: String, val title: String, val excerpt: String?, val imageUrl: String?)

    companion object {
        /** The rotation that fills the hours the web leaves empty. */
        const val ROTATION_ID = "the-best-of-slow-down"

        private val json get() = ScheduleStore.json

        fun parseWeek(text: String): List<DayPost> {
            val posts = json.parseToJsonElement(text).jsonObject["posts"]?.jsonArray ?: return emptyList()
            return posts.map { element ->
                val post = element.jsonObject
                DayPost(
                    title = post.string("post_title") ?: "",
                    slug = post.string("post_name") ?: "",
                    order = (post["menu_order"] as? JsonPrimitive)?.intOrNull,
                    // A day the station emptied comes without its list (or `false`).
                    slots = (post["shows"] as? JsonArray)?.mapNotNull { slot ->
                        val obj = slot as? JsonObject ?: return@mapNotNull null
                        Slot(showIds(obj["show_id"]), obj.string("show_time") ?: "", obj.string("show_time_end") ?: "")
                    } ?: emptyList(),
                )
            }
        }

        /** ["13920"] on the web today; a plain string or number also does. */
        private fun showIds(element: JsonElement?): List<Int> = when (element) {
            is JsonArray -> element.mapNotNull { (it as? JsonPrimitive)?.content?.toIntOrNull() }
            is JsonPrimitive -> listOfNotNull(element.content.toIntOrNull())
            else -> emptyList()
        }

        fun parseShows(text: String): List<WebShow> =
            json.parseToJsonElement(text).jsonArray.mapNotNull { element ->
                val show = element as? JsonObject ?: return@mapNotNull null
                val id = (show["id"] as? JsonPrimitive)?.intOrNull ?: return@mapNotNull null
                val media = ((show["_embedded"] as? JsonObject)?.get("wp:featuredmedia") as? JsonArray)?.firstOrNull() as? JsonObject
                WebShow(
                    id = id,
                    slug = show.string("slug") ?: "",
                    title = HtmlText.plain((show["title"] as? JsonObject)?.string("rendered") ?: ""),
                    excerpt = (show["excerpt"] as? JsonObject)?.string("rendered")?.let(HtmlText::plain),
                    imageUrl = media?.string("source_url"),
                )
            }

        private fun JsonObject.string(key: String): String? = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

        fun build(week: List<DayPost>, shows: List<WebShow>, catalog: List<Show>): List<ScheduleDay> {
            val webShows = shows.associateBy { it.id }
            val byWebId = catalog.filter { it.webID != null }.associateBy { it.webID!! }
            val byName = catalog.associateBy { normalized(it.name) }
            val rotation = catalog.firstOrNull { it.id == ROTATION_ID } ?: throw Incomplete("no rotation")

            fun show(webId: Int): Show? {
                byWebId[webId]?.let { return it }
                val web = webShows[webId] ?: return null
                byName[normalized(web.title)]?.let { return it }
                return Show(
                    id = showId(web.slug, webId), name = web.title, start = "", end = "",
                    imageURL = web.imageUrl, summary = web.excerpt?.takeIf { it.isNotEmpty() }, webID = webId,
                )
            }

            val days = sortedMapOf<Int, ScheduleDay>()
            for (post in week) {
                val weekday = post.weekday ?: continue
                if (days.containsKey(weekday)) continue
                val slots = post.slots.mapNotNull { slot ->
                    val found = slot.showIds.firstOrNull()?.let(::show) ?: return@mapNotNull null
                    val start = minutes(slot.start) ?: return@mapNotNull null
                    val rawEnd = minutes(slot.end) ?: return@mapNotNull null
                    // "00:00" (or an end before the start) closes the day.
                    val end = if (rawEnd <= start) 1440 else minOf(rawEnd, 1440)
                    Triple(found, start, end)
                }.sortedBy { it.second }

                val result = mutableListOf<Show>()
                var cursor = 0
                for ((found, slotStart, end) in slots) {
                    val start = maxOf(slotStart, cursor)
                    if (start >= end) continue
                    if (start > cursor) result += rotation.at(cursor, start)
                    result += found.at(start, end)
                    cursor = end
                }
                if (cursor < 1440) result += rotation.at(cursor, 1440)
                days[weekday] = ScheduleDay(weekday, post.title, result)
            }
            // Every day of the week, or the programme stays as it was.
            if (days.size != 7) throw Incomplete("${days.size} days")
            return days.values.toList()
        }

        /** A special's id in the stats and reminders: its slug in `[a-z0-9-]`. */
        fun showId(slug: String, webId: Int): String {
            val decoded = runCatching { URLDecoder.decode(slug, "UTF-8") }.getOrDefault(slug)
            val folded = fold(decoded)
            val dashed = folded.map { if (it in 'a'..'z' || it in '0'..'9') it else '-' }.joinToString("")
            val id = dashed.split('-').filter { it.isNotEmpty() }.joinToString("-")
            return id.ifEmpty { "web-$webId" }
        }

        fun minutes(time: String): Int? {
            val parts = time.trim().split(":")
            if (parts.size < 2) return null
            val hour = parts[0].toIntOrNull() ?: return null
            val minute = parts[1].toIntOrNull() ?: return null
            if (hour !in 0..24 || minute !in 0..59) return null
            return hour * 60 + minute
        }

        fun time(minutes: Int): String {
            val value = minutes % 1440
            return "%02d:%02d".format(value / 60, value % 60)
        }

        /** Names compared without case, accents or odd spaces (no-break spaces from the web). */
        fun normalized(name: String): String =
            fold(name).split(Regex("[\\s\\u00A0\\u202F]+")).filter { it.isNotEmpty() }.joinToString(" ")

        private fun fold(text: String) =
            Normalizer.normalize(text, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

        private fun Show.at(start: Int, end: Int) = copy(start = time(start), end = time(end))
    }
}

/** WordPress's rendered HTML as plain text, as `HTMLText` on iOS. */
object HtmlText {
    private val named = mapOf(
        "amp" to "&", "quot" to "\"", "apos" to "'", "lt" to "<", "gt" to ">", "nbsp" to " ",
        "ndash" to "–", "mdash" to "—", "hellip" to "…", "lsquo" to "‘", "rsquo" to "’",
        "sbquo" to "‚", "ldquo" to "“", "rdquo" to "”", "bdquo" to "„",
    )

    fun plain(html: String): String {
        var text = html.replace(Regex("<[^>]+>"), " ")
        text = decodeEntities(text).replace("[…]", "…")
        // Swift's .whitespacesAndNewlines includes the no-break space.
        return text.split(Regex("[\\s\\u00A0]+")).filter { it.isNotEmpty() }.joinToString(" ")
    }

    fun decodeEntities(text: String): String =
        Regex("&(#?[A-Za-z0-9]{1,9});").replace(text) { match ->
            val entity = match.groupValues[1]
            val decoded = if (entity.startsWith("#")) {
                val digits = entity.drop(1)
                val value = if (digits.startsWith("x", ignoreCase = true)) digits.drop(1).toIntOrNull(16) else digits.toIntOrNull()
                value?.takeIf { Character.isValidCodePoint(it) }?.let { String(Character.toChars(it)) }
            } else {
                named[entity]
            }
            decoded ?: match.value
        }
}
