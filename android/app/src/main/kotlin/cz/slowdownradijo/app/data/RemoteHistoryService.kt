package cz.slowdownradijo.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.time.Instant
import java.time.OffsetDateTime

/** A row of `played_tracks` (backend/supabase/sql/001_played_tracks.sql). */
@Serializable
data class RemotePlayedTrack(
    val id: String,
    val artist: String,
    val title: String,
    @SerialName("played_at") val playedAtString: String,
    @SerialName("show_name") val showName: String? = null,
) {
    val playedAt: Instant
        get() = runCatching { OffsetDateTime.parse(playedAtString).toInstant() }.getOrDefault(Instant.EPOCH)
}

/**
 * Reads `played_tracks`, which `collect-now-playing` logs every minute,
 * through Supabase's REST API with the public (publishable) key, as
 * `RemoteHistoryService.swift`.
 */
class RemoteHistoryService(
    private val client: OkHttpClient,
    private val baseUrl: String = BASE_URL,
) {
    suspend fun fetchPage(before: Instant?, windowStart: Instant, limit: Int): List<RemotePlayedTrack> =
        withContext(Dispatchers.IO) {
            val url = baseUrl.toHttpUrl().newBuilder()
                .addQueryParameter("select", "id,artist,title,played_at,show_name")
                .addQueryParameter("played_at", "gte.$windowStart")
                .addQueryParameter("order", "played_at.desc")
                .addQueryParameter("limit", "$limit")
                .apply { if (before != null) addQueryParameter("played_at", "lt.$before") }
                .build()
            val request = Request.Builder().url(url)
                .header("apikey", ANON_KEY)
                .header("Authorization", "Bearer $ANON_KEY")
                .build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("played_tracks: ${response.code}")
                ScheduleStore.json.decodeFromString<List<RemotePlayedTrack>>(response.body.string())
            }
        }

    companion object {
        const val BASE_URL = "https://toqoqrshyutyezoyxvlj.supabase.co/rest/v1/played_tracks"
        /** Supabase's publishable key: grants only what RLS allows (public read). */
        const val ANON_KEY = "sb_publishable_KjKHzi03xlmnhNAnxD87oQ_6p-Qb1Su"
    }
}
