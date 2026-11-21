package cz.slowdownradijo.app.stats

import cz.slowdownradijo.app.account.SessionException
import cz.slowdownradijo.app.account.SessionProvider
import cz.slowdownradijo.app.data.RemoteHistoryService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

/** One day's listening to one show, as `ListeningRow` (the server's `p_rows`). */
@Serializable
data class ListeningRow(
    val day: String,
    @SerialName("show_id") val showId: String,
    var seconds: Int,
    /** What really played (`mp3` / `aac`) and the quality setting, server totals only (027). */
    val stream: String? = null,
    val quality: String? = null,
)

/** `get_my_stats` (backend/supabase/sql/005, 009, 017). */
@Serializable
data class StatsSnapshot(
    val available: Boolean,
    @SerialName("total_seconds") val totalSeconds: Int = 0,
    @SerialName("community_seconds") val communitySeconds: Int = 0,
    @SerialName("ranked_listeners") val rankedListeners: Int = 0,
    val rank: Int? = null,
    val daily: List<Row> = emptyList(),
    val shows: List<ShowTotal>? = null,
    /** The places right above and below, and days with listening (026). */
    @SerialName("ahead_seconds") val aheadSeconds: Int? = null,
    @SerialName("behind_seconds") val behindSeconds: Int? = null,
    @SerialName("listening_days") val listeningDays: Int? = null,
) {
    @Serializable
    data class Row(val day: String, @SerialName("show_id") val showId: String, val seconds: Int)

    @Serializable
    data class ShowTotal(@SerialName("show_id") val showId: String, val seconds: Int)
}

/** `public_stats` (backend/supabase/sql/007). */
@Serializable
data class PublicStats(
    val available: Boolean,
    @SerialName("community_seconds") val communitySeconds: Int = 0,
    @SerialName("ranked_listeners") val rankedListeners: Int = 0,
)

/** The listening stats server, as `StatsAPIClient.swift`. */
interface StatsApi {
    suspend fun recordListening(batchId: String, rows: List<ListeningRow>, appVersion: String)
    /** `null` when this phone never uploaded anything (no account to ask about). */
    suspend fun fetchMyStats(): StatsSnapshot?
    suspend fun fetchPublicStats(): PublicStats
    suspend fun deleteMyData()

    sealed class Failure(message: String) : IOException(message) {
        class Transport(cause: Throwable? = null) : Failure("transport: $cause")
        class Server(val code: Int) : Failure("server $code")
        /** 400 / 422: this exact payload will never be accepted. */
        class Rejected(val code: Int) : Failure("rejected $code")
        class AuthFailed : Failure("auth failed")
    }
}

/**
 * The stats functions over plain REST; the session (an anonymous user per phone, made on
 * the first upload, upgraded to a permanent account when the listener signs in) comes
 * from [sessions], shared with the account and the chat. As `StatsAPIClient.swift`.
 */
class SupabaseStatsApi(
    private val client: OkHttpClient,
    private val sessions: SessionProvider,
    private val baseUrl: String = "https://toqoqrshyutyezoyxvlj.supabase.co",
) : StatsApi {
    @Serializable
    private data class RecordBody(
        @SerialName("p_batch_id") val batchId: String,
        @SerialName("p_rows") val rows: List<ListeningRow>,
        @SerialName("p_app_version") val appVersion: String,
    )

    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    override suspend fun recordListening(batchId: String, rows: List<ListeningRow>, appVersion: String) {
        authenticatedRpc("record_listening", json.encodeToString(RecordBody.serializer(), RecordBody(batchId, rows, appVersion)), createAnonymous = true)
    }

    override suspend fun fetchMyStats(): StatsSnapshot? =
        authenticatedRpc("get_my_stats", "{}", createAnonymous = false)?.let { json.decodeFromString<StatsSnapshot>(it) }

    override suspend fun fetchPublicStats(): PublicStats =
        json.decodeFromString(send("rest/v1/rpc/public_stats", body = "{}", bearer = null))

    override suspend fun deleteMyData() {
        // No session: nothing was ever uploaded, and asking would create an account just to delete it.
        authenticatedRpc("delete_my_listening_data", "{}", createAnonymous = false) ?: return
        // An anonymous listener's user is gone on the server; a signed-in one keeps the account.
        sessions.forgetIfAnonymous()
    }

    /** `null` when there's no session and [createAnonymous] is false. */
    private suspend fun authenticatedRpc(name: String, body: String, createAnonymous: Boolean): String? {
        val path = "rest/v1/rpc/$name"
        val token = mapSession { sessions.accessToken(createAnonymous) } ?: return null
        return try {
            send(path, body = body, bearer = token)
        } catch (e: StatsApi.Failure.Server) {
            if (e.code != 401) throw e
            // Revoked on the server: renew once and retry.
            send(path, body = body, bearer = mapSession { sessions.refreshedAccessToken() })
        }
    }

    private suspend fun <T> mapSession(block: suspend () -> T): T = try {
        block()
    } catch (e: SessionException.Transport) {
        throw StatsApi.Failure.Transport(e)
    } catch (_: SessionException) {
        throw StatsApi.Failure.AuthFailed()
    }

    private suspend fun send(path: String, query: Pair<String, String>? = null, body: String, bearer: String?): String =
        withContext(Dispatchers.IO) {
            val url = "$baseUrl/$path".toHttpUrl().newBuilder().apply { query?.let { addQueryParameter(it.first, it.second) } }.build()
            val request = Request.Builder().url(url)
                .post(body.toRequestBody("application/json".toMediaType()))
                .header("apikey", RemoteHistoryService.ANON_KEY)
                .apply { if (bearer != null) header("Authorization", "Bearer $bearer") }
                .build()
            val response = try {
                client.newCall(request).execute()
            } catch (e: IOException) {
                throw StatsApi.Failure.Transport(e)
            }
            response.use {
                when (it.code) {
                    in 200..299 -> it.body.string()
                    400, 422 -> throw StatsApi.Failure.Rejected(it.code)
                    else -> throw StatsApi.Failure.Server(it.code)
                }
            }
        }

}
