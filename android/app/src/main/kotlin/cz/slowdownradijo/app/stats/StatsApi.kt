package cz.slowdownradijo.app.stats

import android.content.SharedPreferences
import cz.slowdownradijo.app.data.RemoteHistoryService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
data class ListeningRow(val day: String, @SerialName("show_id") val showId: String, var seconds: Int)

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
 * Supabase with an anonymous account per phone: signed up on the first
 * upload, the session kept in [prefs] and refreshed when it runs out.
 */
class SupabaseStatsApi(
    private val client: OkHttpClient,
    private val prefs: SharedPreferences,
    private val baseUrl: String = "https://toqoqrshyutyezoyxvlj.supabase.co",
    private val now: () -> Long = System::currentTimeMillis,
) : StatsApi {
    @Serializable
    private data class Session(val accessToken: String, val refreshToken: String, val expiresAt: Long)

    @Serializable
    private data class AuthResponse(
        @SerialName("access_token") val accessToken: String,
        @SerialName("refresh_token") val refreshToken: String,
        @SerialName("expires_in") val expiresIn: Long,
    )

    @Serializable
    private data class RecordBody(
        @SerialName("p_batch_id") val batchId: String,
        @SerialName("p_rows") val rows: List<ListeningRow>,
        @SerialName("p_app_version") val appVersion: String,
    )

    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val mutex = Mutex()
    private var session: Session? = prefs.getString(SESSION, null)?.let { runCatching { json.decodeFromString<Session>(it) }.getOrNull() }

    override suspend fun recordListening(batchId: String, rows: List<ListeningRow>, appVersion: String) {
        authenticatedRpc("record_listening", json.encodeToString(RecordBody.serializer(), RecordBody(batchId, rows, appVersion)))
    }

    override suspend fun fetchMyStats(): StatsSnapshot? {
        if (session == null) return null
        return json.decodeFromString<StatsSnapshot>(authenticatedRpc("get_my_stats", "{}"))
    }

    override suspend fun fetchPublicStats(): PublicStats =
        json.decodeFromString(send("rest/v1/rpc/public_stats", body = "{}", bearer = null))

    override suspend fun deleteMyData() {
        // No session: nothing was ever uploaded, and asking would create an account just to delete it.
        if (session == null) return
        authenticatedRpc("delete_my_listening_data", "{}")
        session = null
        prefs.edit().remove(SESSION).apply()
    }

    private suspend fun currentSession(): Session = mutex.withLock {
        session?.takeIf { it.expiresAt - now() > 60_000 } ?: renewSession()
    }

    private suspend fun renewSession(): Session {
        session?.let { stored ->
            try {
                return store(send("auth/v1/token", query = "grant_type" to "refresh_token", body = """{"refresh_token":"${stored.refreshToken}"}""", bearer = null))
            } catch (_: StatsApi.Failure.Rejected) {
                // The refresh token is no longer valid: a new anonymous user below.
            }
            // Network or server trouble propagates: keep the identity, retry later.
        }
        return try {
            store(send("auth/v1/signup", body = "{}", bearer = null))
        } catch (e: StatsApi.Failure.Transport) {
            throw e
        } catch (_: Exception) {
            throw StatsApi.Failure.AuthFailed()
        }
    }

    private fun store(response: String): Session {
        val auth = runCatching { json.decodeFromString<AuthResponse>(response) }.getOrNull() ?: throw StatsApi.Failure.AuthFailed()
        val fresh = Session(auth.accessToken, auth.refreshToken, now() + auth.expiresIn * 1000)
        session = fresh
        prefs.edit().putString(SESSION, json.encodeToString(Session.serializer(), fresh)).apply()
        return fresh
    }

    private suspend fun authenticatedRpc(name: String, body: String): String {
        val path = "rest/v1/rpc/$name"
        val current = currentSession()
        return try {
            send(path, body = body, bearer = current.accessToken)
        } catch (e: StatsApi.Failure.Server) {
            if (e.code != 401) throw e
            // Revoked on the server: renew once and retry.
            val renewed = mutex.withLock { renewSession() }
            send(path, body = body, bearer = renewed.accessToken)
        }
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

    private companion object {
        const val SESSION = "supabase.session"
    }
}
