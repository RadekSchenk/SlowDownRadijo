package cz.slowdownradijo.app.data

import kotlinx.serialization.Serializable

/** A show in the weekly catalogue, as in `SlowDownRadijo/Models/Show.swift`. */
@Serializable
data class Show(
    val id: String,
    val name: String,
    /** "HH:mm", Prague time. */
    val start: String,
    /** "HH:mm"; "00:00" or "24:00" ends at midnight. */
    val end: String,
    val imageURL: String? = null,
    val language: String? = null,
    val hostName: String? = null,
    /** An iOS imageset name (e.g. "HostDjPufaz"), see [SharedImages]. */
    val hostImageName: String? = null,
    /** A bundled square show photo (`ShowArt…`), preferred over [imageURL]. */
    val artworkName: String? = null,
    /** The show's own title without the " s <host>" that [name] carries. */
    val title: String? = null,
    val summary: String? = null,
    val summaryEn: String? = null,
    /** The show's post id on slowdownradijo.cz (`/wp-json/wp/v2/shows`). */
    val webID: Int? = null,
) {
    val displayTitle: String get() = title ?: name

    /** The description in the app's language (English falls back to Czech). */
    fun localizedSummary(english: Boolean): String? = if (english) summaryEn ?: summary else summary

    /** [name] with its Czech " s <host>" as " with " in English. */
    fun localizedName(english: Boolean): String {
        if (!english || title == null) return name
        val at = name.indexOf(" s ")
        return if (at < 0) name else name.replaceRange(at, at + 3, " with ")
    }
}

@Serializable
data class ScheduleDay(
    /** Sunday-first, 1...7, as iOS `Calendar`. */
    val weekday: Int,
    val dayName: String,
    val shows: List<Show>,
)

@Serializable
data class Schedule(val days: List<ScheduleDay>)
