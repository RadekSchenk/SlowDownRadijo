package cz.slowdownradijo.app.chat

import android.content.SharedPreferences
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.data.Show
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.decodeRecord
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import java.time.Duration
import java.time.Instant

/**
 * The listeners' chat, as `ChatService.swift`: one stream for the whole radio, read
 * by anyone, written by signed-in listeners. Loads the last week, then follows
 * `chat_messages` over Realtime while the app is in the foreground ([resume] /
 * [pause] from `MainActivity`).
 */
class ChatService(
    private val supabase: SupabaseClient,
    private val account: AccountService,
    private val prefs: SharedPreferences,
    private val scope: CoroutineScope,
) {
    data class State(
        /** Oldest first. */
        val messages: List<ChatMessage> = emptyList(),
        val outgoing: List<OutgoingChatMessage> = emptyList(),
        /** The show the listener's unsent messages go under (id, title). */
        val outgoingShow: Pair<String?, String?> = null to null,
        val pinned: ChatMessage? = null,
        val hidden: Set<String> = emptySet(),
        val loaded: Boolean = false,
        val loadFailed: Boolean = false,
        /** The newest message seen on the home page or in the chat (the ticker plays from here). */
        val lastSeenId: Long = 0,
    ) {
        val visibleMessages: List<ChatMessage> get() = messages.filter { it.userId == null || it.userId !in hidden }
    }

    private val _state = MutableStateFlow(State(lastSeenId = prefs.getLong(LAST_SEEN_KEY, 0)))
    val state: StateFlow<State> = _state.asStateFlow()

    private var channel: RealtimeChannel? = null
    private var listenJob: Job? = null
    private var started = false

    fun start() {
        if (started) return
        started = true
        // Signing in or out changes whose messages are hidden.
        account.state.map { it is AccountService.State.SignedIn }.distinctUntilChanged().drop(1)
            .onEach { refreshHidden() }.launchIn(scope)
    }

    fun resume() {
        start()
        scope.launch {
            reload()
            subscribe()
            refreshHidden()
        }
    }

    fun pause() {
        listenJob?.cancel()
        listenJob = null
        val old = channel ?: return
        channel = null
        scope.launch { runCatching { old.unsubscribe(); supabase.realtime.removeChannel(old) } }
    }

    suspend fun reload() {
        val since = Instant.now().minus(Duration.ofDays(HISTORY_DAYS))
        try {
            val recent = supabase.postgrest.from("chat_messages").select {
                filter { gte("created_at", since.toString()) }
                order("created_at", Order.DESCENDING)
                limit(HISTORY_LIMIT)
            }.decodeList<ChatMessage>()
            val pins = supabase.postgrest.from("chat_messages").select {
                filter { filterNot("pinned_at", io.github.jan.supabase.postgrest.query.filter.FilterOperator.IS, "null") }
                order("pinned_at", Order.DESCENDING)
                limit(1)
            }.decodeList<ChatMessage>()
            _state.value = _state.value.copy(
                messages = recent.reversed(),
                pinned = pins.firstOrNull()?.takeUnless { it.isDeleted },
                loaded = true,
                loadFailed = false,
            )
            val newest = _state.value.messages.lastOrNull()
            // First time: nothing is "new" yet, no ticker to play.
            if (_state.value.lastSeenId == 0L && newest != null) setLastSeen(newest.id)
        } catch (e: Exception) {
            if (!_state.value.loaded) _state.value = _state.value.copy(loadFailed = true)
        }
    }

    private suspend fun subscribe() {
        if (channel != null) return
        val channel = supabase.channel("chat-messages")
        this.channel = channel
        val changes = channel.postgresChangeFlow<PostgresAction>(schema = "public") { table = "chat_messages" }
        listenJob = changes.onEach { action ->
            when (action) {
                is PostgresAction.Insert -> runCatching { action.decodeRecord<ChatMessage>() }.getOrNull()?.let(::upsert)
                is PostgresAction.Update -> runCatching { action.decodeRecord<ChatMessage>() }.getOrNull()?.let(::upsert)
                is PostgresAction.Delete -> action.oldRecord["id"]?.jsonPrimitive?.longOrNull?.let { id ->
                    _state.value = _state.value.copy(messages = _state.value.messages.filterNot { it.id == id })
                }
                else -> Unit
            }
        }.launchIn(scope)
        runCatching { channel.subscribe() }.onFailure {
            listenJob?.cancel()
            listenJob = null
            this.channel = null
        }
    }

    private fun upsert(message: ChatMessage) {
        val s = _state.value
        val list = s.messages.toMutableList()
        val index = list.indexOfFirst { it.id == message.id }
        if (index >= 0) list[index] = message
        else {
            val at = list.indexOfFirst { it.createdAt > message.createdAt }.let { if (it < 0) list.size else it }
            list.add(at, message)
        }
        val pinned = when {
            message.pinnedAt != null && !message.isDeleted &&
                (s.pinned == null || message.pinnedAt!! >= (s.pinned.pinnedAt ?: Instant.EPOCH)) -> message
            s.pinned?.id == message.id && (message.pinnedAt == null || message.isDeleted) -> null
            else -> s.pinned
        }
        _state.value = s.copy(messages = list, pinned = pinned)
    }

    // Seen

    fun markSeen() {
        _state.value.messages.lastOrNull()?.let { markSeen(it.id) }
    }

    fun markSeen(upTo: Long) {
        if (upTo > _state.value.lastSeenId) setLastSeen(upTo)
    }

    private fun setLastSeen(id: Long) {
        _state.value = _state.value.copy(lastSeenId = id)
        prefs.edit().putLong(LAST_SEEN_KEY, id).apply()
    }

    // Hidden listeners

    suspend fun refreshHidden() {
        if (account.state.value !is AccountService.State.SignedIn) {
            _state.value = _state.value.copy(hidden = emptySet())
            return
        }
        runCatching { account.hiddenUsers() }.getOrNull()?.let { users ->
            _state.value = _state.value.copy(hidden = users.map { it.userId }.toSet())
        }
    }

    // Sending

    /**
     * Sends [rawBody] under the show on air (the app knows the programme; the server
     * only checks it). Shows "sending…" at once; on failure the message stays with
     * "Zkusit znovu", except for errors the listener must act on (muted, no
     * nickname), which are thrown.
     */
    suspend fun send(rawBody: String, show: Show?) {
        val body = rawBody.trim().take(500)
        if (body.isEmpty()) return
        val pending = OutgoingChatMessage(body = body, createdAt = Instant.now())
        _state.value = _state.value.copy(
            outgoing = _state.value.outgoing + pending,
            outgoingShow = show?.id to show?.displayTitle,
        )
        deliver(pending.id)
    }

    suspend fun retry(id: String) {
        updateOutgoing(id) { it.copy(failed = false) }
        deliver(id)
    }

    private fun updateOutgoing(id: String, change: (OutgoingChatMessage) -> OutgoingChatMessage) {
        _state.value = _state.value.copy(outgoing = _state.value.outgoing.map { if (it.id == id) change(it) else it })
    }

    private fun removeOutgoing(id: String) {
        _state.value = _state.value.copy(outgoing = _state.value.outgoing.filterNot { it.id == id })
    }

    private suspend fun deliver(id: String) {
        val pending = _state.value.outgoing.firstOrNull { it.id == id } ?: return
        val (showId, showTitle) = _state.value.outgoingShow
        try {
            val message = supabase.postgrest.rpc(
                "send_chat_message",
                buildJsonObject {
                    put("p_body", pending.body)
                    put("p_show_id", showId)
                    put("p_show_title", showTitle)
                },
            ).decodeAs<ChatMessage>()
            removeOutgoing(id)
            upsert(message)
            markSeen(message.id)
        } catch (e: Exception) {
            val error = AccountError.from(e)
            when (error) {
                is AccountError.Muted, AccountError.Blocked, AccountError.NicknameRequired, AccountError.NotSignedIn,
                AccountError.AccountRequired, AccountError.MessageInvalid -> {
                    removeOutgoing(id)
                    if (error is AccountError.Muted || error == AccountError.Blocked) account.refresh()
                }
                else -> updateOutgoing(id) { it.copy(failed = true) }
            }
            throw error
        }
    }

    /** Screenshot tests. */
    internal fun preview(state: State) {
        _state.value = state
    }

    companion object {
        const val HISTORY_DAYS = 7L
        const val HISTORY_LIMIT = 300L
        private const val LAST_SEEN_KEY = "lastSeenId"
    }
}
