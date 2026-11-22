package cz.slowdownradijo.app.contests

import android.content.SharedPreferences
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.account.SupabaseSessionProvider
import cz.slowdownradijo.app.analytics.Analytics
import cz.slowdownradijo.app.analytics.AnalyticsEvent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The contest on the home screen (Figma "Soutěže" H1–H3, D1–D9), as
 * `ContestService.swift`: backend/supabase/sql/028_contests.sql, `contest_current`,
 * `contest_enter`, `contest_dismiss`.
 *
 * Everyone sees the running contest; only registered Slowriders can enter. Closing
 * the card is remembered on the phone at once and on the server when the phone has
 * a session, so it stays away on the listener's other phones too.
 */
class ContestService(
    private val supabase: SupabaseClient,
    private val sessions: SupabaseSessionProvider,
    private val prefs: SharedPreferences,
    private val analytics: () -> Analytics,
    private val scope: CoroutineScope,
) {
    @Serializable
    data class Entry(
        val answer: String,
        val phone: String? = null,
        @SerialName("created_at") val createdAtText: String? = null,
    ) {
        val createdAt: Instant? get() = createdAtText?.let(::parseInstant)
    }

    @Serializable
    data class Contest(
        val id: Long,
        val title: String,
        val body: String,
        val question: String,
        @SerialName("answer_type") val answerType: String = "text",
        val options: List<String> = emptyList(),
        val prize: String = "",
        @SerialName("winners_count") val winnersCount: Int = 1,
        @SerialName("rules_url") val rulesUrl: String? = null,
        @SerialName("ends_at") val endsAtText: String,
        @SerialName("my_status") val myStatus: String? = null,
        @SerialName("my_entry") val myEntry: Entry? = null,
    ) {
        val endsAt: Instant get() = parseInstant(endsAtText) ?: Instant.MAX
        val isChoice: Boolean get() = answerType == "choice"
        val entered: Boolean get() = myStatus == "entered"
        fun isRunning(now: Instant = Instant.now()) = endsAt.isAfter(now)

        /** "A · Weekend Aftertaste" for a letter answer, else the words. */
        fun answerLabel(answer: String): String {
            val index = LETTERS.indexOf(answer)
            return if (isChoice && index in options.indices) "$answer · ${options[index]}" else answer
        }
    }

    enum class Failure { CLOSED, ALREADY_ENTERED, ANSWER_INVALID, PHONE_INVALID, ACCOUNT_REQUIRED, OFFLINE, OTHER }

    class ContestException(val failure: Failure) : Exception(failure.name)

    private val _current = MutableStateFlow<Contest?>(null)
    val current: StateFlow<Contest?> = _current.asStateFlow()

    private val _dismissed = MutableStateFlow(readDismissed())
    val dismissed: StateFlow<Set<Long>> = _dismissed.asStateFlow()

    private val shownThisLaunch = mutableSetOf<Long>()
    private var endWatch: Job? = null

    /** A sample contest without the server (debug screenshots, `ContestDemo`). */
    var demo: Contest? = null

    /** The home card shows: a running contest the listener hasn't entered or closed. */
    fun infoboxContest(contest: Contest?, dismissed: Set<Long>, now: Instant = Instant.now()): Contest? =
        contest?.takeIf { it.isRunning(now) && it.myStatus == null && it.id !in dismissed }

    suspend fun refresh() {
        demo?.let { if (_current.value == null) _current.value = it; return }
        try {
            // A session's token rides along when there is one; without one the
            // publishable key is enough (`contest_current` is public).
            runCatching { sessions.accessToken(createAnonymous = false) }
            val data = supabase.postgrest.rpc("contest_current").data
            val contest = if (data.isBlank() || data.trim() == "null") null else json.decodeFromString<Contest>(data)
            _current.value = contest
            watchEnd(contest)
        } catch (_: Exception) {
            // Offline: keep what we had.
        }
    }

    private fun watchEnd(contest: Contest?) {
        endWatch?.cancel()
        val left = contest?.let { Duration.between(Instant.now(), it.endsAt) } ?: return
        if (left.isNegative || left > Duration.ofDays(7)) return
        endWatch = scope.launch {
            delay(left.toMillis() + 1_000)
            _current.value = _current.value // re-evaluated by the UI with the new time
            refresh()
        }
    }

    fun infoboxShown(contest: Contest) {
        if (shownThisLaunch.add(contest.id)) analytics().track(AnalyticsEvent.ContestInfoboxShown(contest.id))
    }

    /** "Zavřít a nesoutěžit" (H2). */
    fun dismiss(contest: Contest) {
        val next = (_dismissed.value + contest.id).toList().takeLast(50).toSet()
        _dismissed.value = next
        prefs.edit().putString(DISMISSED_KEY, next.joinToString(",")).apply()
        analytics().track(AnalyticsEvent.ContestInfoboxDismissed(contest.id))
        if (demo != null) return
        scope.launch {
            val token = runCatching { sessions.accessToken(createAnonymous = false) }.getOrNull() ?: return@launch
            if (token.isNotEmpty()) runCatching {
                supabase.postgrest.rpc("contest_dismiss", buildJsonObject { put("p_contest_id", contest.id) })
            }
        }
    }

    suspend fun enter(contest: Contest, answer: String, phone: String): Entry {
        if (demo != null) {
            delay(1_000)
            val normalized = normalizedPhone(phone) ?: throw ContestException(Failure.PHONE_INVALID)
            val entry = Entry(answer, normalized, Instant.now().toString())
            _current.value = _current.value?.copy(myStatus = "entered", myEntry = entry)
            return entry
        }
        try {
            val entry = supabase.postgrest.rpc("contest_enter", buildJsonObject {
                put("p_contest_id", contest.id)
                put("p_answer", answer)
                put("p_phone", phone)
            }).let { json.decodeFromString<Entry>(it.data) }
            if (_current.value?.id == contest.id) _current.value = _current.value?.copy(myStatus = "entered", myEntry = entry)
            analytics().track(AnalyticsEvent.ContestEntrySubmitted(contest.id, contest.answerType, success = true, error = null))
            return entry
        } catch (e: Exception) {
            val failure = failure(e)
            analytics().track(AnalyticsEvent.ContestEntrySubmitted(contest.id, contest.answerType, success = false, error = failure.analyticsName))
            if (failure == Failure.ALREADY_ENTERED || failure == Failure.CLOSED) refresh()
            throw ContestException(failure)
        }
    }

    private fun readDismissed(): Set<Long> =
        prefs.getString(DISMISSED_KEY, null).orEmpty().split(',').mapNotNull { it.toLongOrNull() }.toSet()

    companion object {
        val LETTERS = listOf("A", "B", "C")
        private const val DISMISSED_KEY = "dismissed"
        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

        /** The same names as iOS's `Failure` cases, for `contest_entry_submitted`. */
        val Failure.analyticsName: String get() = when (this) {
            Failure.CLOSED -> "closed"
            Failure.ALREADY_ENTERED -> "alreadyEntered"
            Failure.ANSWER_INVALID -> "answerInvalid"
            Failure.PHONE_INVALID -> "phoneInvalid"
            Failure.ACCOUNT_REQUIRED -> "accountRequired"
            Failure.OFFLINE -> "offline"
            Failure.OTHER -> "other"
        }

        fun failure(e: Throwable): Failure = when (val error = AccountError.from(e)) {
            AccountError.Offline -> Failure.OFFLINE
            AccountError.AccountRequired, AccountError.NotSignedIn -> Failure.ACCOUNT_REQUIRED
            is AccountError.Unknown -> when (error.detail) {
                "contest_closed" -> Failure.CLOSED
                "already_entered" -> Failure.ALREADY_ENTERED
                "answer_invalid" -> Failure.ANSWER_INVALID
                "phone_invalid" -> Failure.PHONE_INVALID
                else -> Failure.OTHER
            }
            else -> Failure.OTHER
        }

        /**
         * The same rules as `contest_normalize_phone`: a Czech number with or without
         * +420 / 00420, or any number with its country code. Null when it isn't one.
         */
        fun normalizedPhone(raw: String): String? {
            var s = raw.filterNot { it in " -()./ " }
            if (s.startsWith("00") && s.drop(2).all { it in '0'..'9' }) s = "+" + s.drop(2)
            if (s.length == 9 && s.all { it in '0'..'9' }) s = "+420$s"
            if (!s.startsWith("+") || s.length < 2 || !s.drop(1).all { it in '0'..'9' }) return null
            val digits = s.drop(1)
            if (digits.startsWith("420")) return if (digits.length == 12) s else null
            return if (digits.first() != '0' && digits.length in 8..15) s else null
        }

        /** `timestamptz` inside JSON, with or without the T and 0–6 fraction digits. */
        fun parseInstant(text: String): Instant? {
            val normalized = text.trim().replace(' ', 'T').let { if (Regex("[+-]\\d{2}$").containsMatchIn(it)) "$it:00" else it }
            return runCatching { OffsetDateTime.parse(normalized).toInstant() }.getOrNull()
                ?: runCatching { Instant.parse(normalized) }.getOrNull()
        }
    }
}

/** Dates on the contest screens, in the station's time zone (`ContestFormat` on iOS). */
object ContestFormat {
    private val zone = ZoneId.of("Europe/Prague")

    /** "neděle 30. 11., 23:59" / "Sunday 30 Nov, 23:59". */
    fun dayAndTime(at: Instant, english: Boolean): String = format(at, english, "EEEE d. M., H:mm", "EEEE d MMM, HH:mm")

    /** "30. 11." / "30 Nov". */
    fun day(at: Instant, english: Boolean): String = format(at, english, "d. M.", "d MMM")

    /** "30. 11. v 8:14" / "30 Nov, 08:14". */
    fun dayTimeShort(at: Instant, english: Boolean): String = format(at, english, "d. M. 'v' H:mm", "d MMM, HH:mm")

    /** "+420777123456" → "+420 777 123 456"; other numbers as they are. */
    fun phone(phone: String): String {
        if (!phone.startsWith("+420") || phone.length != 13) return phone
        val d = phone.drop(4)
        return "+420 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 9)}"
    }

    private fun format(at: Instant, english: Boolean, cs: String, en: String): String =
        DateTimeFormatter.ofPattern(if (english) en else cs, if (english) Locale.UK else Locale.forLanguageTag("cs-CZ"))
            .format(at.atZone(zone))
}
