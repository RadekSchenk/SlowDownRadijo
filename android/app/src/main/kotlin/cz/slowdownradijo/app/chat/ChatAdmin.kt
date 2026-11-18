package cz.slowdownradijo.app.chat

import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.data.ScheduleDay
import cz.slowdownradijo.app.data.Show
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.text.Normalizer
import java.time.Instant

/**
 * The superadmin's "Správa chatu" (Figma Profil M10, A1–A6), as `ChatAdmin.swift`:
 * moderators from the programme and their invite links, and the admins
 * (backend/supabase/sql/022_chat_v3.sql, `admin_*`).
 */
class ChatAdmin(private val supabase: SupabaseClient) {
    @Serializable
    data class Host(
        @SerialName("host_id") val hostId: String,
        @SerialName("display_name") val displayName: String,
        val linked: Boolean = false,
        @SerialName("linked_at") val linkedAtText: String? = null,
        @SerialName("invite_expires_at") val inviteExpiresAtText: String? = null,
    ) {
        val linkedAt: Instant? get() = linkedAtText?.let(ChatMessage::parse)
        val inviteExpiresAt: Instant? get() = inviteExpiresAtText?.let(ChatMessage::parse)
    }

    @Serializable
    data class Admin(
        @SerialName("user_id") val userId: String,
        val nickname: String? = null,
        @SerialName("is_superadmin") val isSuperadmin: Boolean = false,
        @SerialName("admin_since") val adminSinceText: String? = null,
        @SerialName("is_me") val isMe: Boolean = false,
    ) {
        val adminSince: Instant? get() = adminSinceText?.let(ChatMessage::parse)
    }

    @Serializable
    data class Overview(val hosts: List<Host> = emptyList(), val admins: List<Admin> = emptyList())

    @Serializable
    data class Invite(
        val code: String,
        @SerialName("expires_at") val expiresAtText: String? = null,
        @SerialName("host_id") val hostId: String,
    ) {
        val expiresAt: Instant? get() = expiresAtText?.let(ChatMessage::parse)
        val url: String get() = "https://slowdownradijo.cz/dj/$code"
    }

    @Serializable
    data class FoundUser(
        @SerialName("user_id") val userId: String,
        val nickname: String? = null,
        @SerialName("registered_at") val registeredAtText: String? = null,
        @SerialName("is_admin") val isAdmin: Boolean = false,
    ) {
        val registeredAt: Instant? get() = registeredAtText?.let(ChatMessage::parse)
    }

    /** A moderator as the programme knows them: one name, maybe several shows. */
    data class ProgrammeHost(val id: String, val name: String, val shows: List<String>)

    private val _overview = MutableStateFlow<Overview?>(null)
    val overview: StateFlow<Overview?> = _overview.asStateFlow()

    private suspend fun rpc(name: String, params: JsonObject = buildJsonObject {}) = try {
        supabase.postgrest.rpc(name, params)
    } catch (e: Exception) {
        throw AccountError.from(e)
    }

    suspend fun reload() {
        _overview.value = rpc("admin_overview").decodeAs<Overview>()
    }

    suspend fun createInvite(hostId: String, name: String): Invite {
        val invite = rpc("admin_create_host_invite", buildJsonObject {
            put("p_host_id", hostId)
            put("p_display_name", name)
        }).decodeAs<Invite>()
        runCatching { reload() }
        return invite
    }

    suspend fun unlink(hostId: String) {
        rpc("admin_unlink_host", buildJsonObject { put("p_host_id", hostId) })
        runCatching { reload() }
    }

    suspend fun findUsers(query: String): List<FoundUser> =
        rpc("admin_find_users", buildJsonObject { put("p_query", query) }).decodeList()

    suspend fun setAdmin(userId: String, on: Boolean) {
        rpc("admin_set_admin", buildJsonObject {
            put("p_user", userId)
            put("p_on", on)
        })
        runCatching { reload() }
    }

    companion object {
        /** The moderators in the programme, each once with all their shows. */
        fun programmeHosts(days: List<ScheduleDay>, catalog: List<Show>): List<ProgrammeHost> {
            val names = linkedMapOf<String, String>()
            val shows = mutableMapOf<String, MutableList<String>>()
            for (show in days.flatMap { it.shows } + catalog) {
                val name = show.hostName?.trim()?.takeIf { it.isNotEmpty() } ?: continue
                val id = hostId(name)
                names.putIfAbsent(id, name)
                val list = shows.getOrPut(id) { mutableListOf() }
                if (show.displayTitle !in list) list += show.displayTitle
            }
            return names.map { (id, name) -> ProgrammeHost(id, name, shows[id].orEmpty()) }.sortedBy { it.name.lowercase() }
        }

        /** "DJ Pufaz" → "dj-pufaz", as `chat_hosts.host_id`. */
        fun hostId(name: String): String {
            val folded = Normalizer.normalize(name, Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").lowercase()
            return folded.replace(Regex("[^a-z0-9]+"), "-").trim('-').take(80)
        }
    }
}
