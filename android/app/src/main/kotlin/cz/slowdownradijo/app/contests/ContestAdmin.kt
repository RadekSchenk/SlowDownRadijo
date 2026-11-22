package cz.slowdownradijo.app.contests

import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.analytics.Analytics
import cz.slowdownradijo.app.analytics.AnalyticsEvent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

/**
 * Profil ▸ Správa ▸ Soutěže for admins and the superadmin (Figma "Soutěže" S1–S6),
 * as `ContestAdmin.swift`: `admin_contests`, `admin_create_contest`,
 * `admin_end_contest`, `admin_contest`, `admin_draw_winners`.
 */
class ContestAdmin(
    private val supabase: SupabaseClient,
    private val contests: ContestService,
    private val analytics: () -> Analytics,
) {
    @Serializable
    data class Summary(
        val id: Long,
        val title: String,
        @SerialName("answer_type") val answerType: String = "choice",
        val prize: String = "",
        @SerialName("winners_count") val winnersCount: Int = 1,
        @SerialName("starts_at") val startsAtText: String? = null,
        @SerialName("ends_at") val endsAtText: String? = null,
        @SerialName("ended_at") val endedAtText: String? = null,
        @SerialName("ended_early") val endedEarly: Boolean = false,
        @SerialName("drawn_at") val drawnAtText: String? = null,
        @SerialName("is_running") val isRunning: Boolean = false,
        val entries: Int = 0,
        val correct: Int = 0,
        val dismissed: Int = 0,
        val winners: Int = 0,
    ) {
        val startsAt: Instant? get() = startsAtText?.let(ContestService::parseInstant)
        val endsAt: Instant? get() = endsAtText?.let(ContestService::parseInstant)
        val drawnAt: Instant? get() = drawnAtText?.let(ContestService::parseInstant)
        /** When it stopped taking answers. */
        val endTime: Instant? get() = endedAtText?.let(ContestService::parseInstant) ?: endsAt
    }

    @Serializable
    data class Overview(val current: Summary? = null, val previous: List<Summary> = emptyList())

    @Serializable
    data class Person(
        val nickname: String? = null,
        val answer: String? = null,
        @SerialName("is_correct") val isCorrect: Boolean? = null,
        val phone: String? = null,
        @SerialName("created_at") val createdAtText: String? = null,
        @SerialName("drawn_at") val drawnAtText: String? = null,
    ) {
        val at: Instant? get() = (createdAtText ?: drawnAtText)?.let(ContestService::parseInstant)
    }

    @Serializable
    data class Bucket(val answer: String, val count: Int)

    @Serializable
    data class DetailData(
        val question: String = "",
        val options: List<String> = emptyList(),
        @SerialName("correct_option") val correctOption: Int? = null,
        val distribution: List<Bucket> = emptyList(),
        @SerialName("entry_list") val entries: List<Person> = emptyList(),
        @SerialName("winners_list") val winners: List<Person> = emptyList(),
    )

    data class Detail(val summary: Summary, val data: DetailData) {
        val question get() = data.question
        val options get() = data.options
        val correctOption get() = data.correctOption
        val distribution: Map<String, Int> get() = data.distribution.associate { it.answer to it.count }
        val entries get() = data.entries
        val winners get() = data.winners

        fun answerLabel(answer: String?): String {
            answer ?: return ""
            val index = ContestService.LETTERS.indexOf(answer)
            return if (summary.answerType == "choice" && index in options.indices) "$answer · ${options[index]}" else answer
        }

        /** The answers as CSV, for handing over the prizes. */
        val csv: String get() {
            fun cell(text: String?) = "\"" + (text ?: "").replace("\"", "\"\"") + "\""
            val winnerNames = winners.mapNotNull { it.nickname }.toSet()
            return (listOf("nickname,answer,correct,phone,sent_at,winner") + entries.map { e ->
                listOf(
                    cell(e.nickname), cell(answerLabel(e.answer)), e.isCorrect?.let { if (it) "yes" else "no" } ?: "",
                    cell(e.phone), e.at?.toString() ?: "", if (e.nickname in winnerNames) "yes" else "",
                ).joinToString(",")
            }).joinToString("\n")
        }

        companion object {
            fun decode(text: String) = Detail(
                ContestService.json.decodeFromString<Summary>(text),
                ContestService.json.decodeFromString<DetailData>(text),
            )
        }
    }

    /** What S3 sends. */
    data class Draft(
        val title: String = "",
        val body: String = "",
        val question: String = "",
        val isChoice: Boolean = true,
        val options: List<String> = listOf("", "", ""),
        val correctOption: Int? = null,
        val prize: String = "",
        val winnersCount: Int = 1,
        val rulesUrl: String = "",
        val endsAt: Instant = defaultEnd(),
    ) {
        enum class Field { TITLE, BODY, QUESTION, OPTIONS, PRIZE, WINNERS, RULES, END }

        /** The same checks as `admin_create_contest`, shown before sending. */
        fun problems(now: Instant = Instant.now()): Set<Field> = buildSet {
            if (title.trim().length !in 3..60) add(Field.TITLE)
            if (body.trim().length !in 10..3000) add(Field.BODY)
            if (question.trim().length !in 5..200) add(Field.QUESTION)
            if (isChoice && (options.any { it.trim().length !in 1..80 } || correctOption == null)) add(Field.OPTIONS)
            if (prize.trim().length !in 2..40) add(Field.PRIZE)
            if (winnersCount !in 1..20) add(Field.WINNERS)
            if (!Regex("^(https?://)?[A-Za-z0-9.-]+\\.[A-Za-z]{2,}(/\\S*)?$").matches(rulesUrl.trim())) add(Field.RULES)
            if (!endsAt.isAfter(now.plus(Duration.ofMinutes(10)))) add(Field.END)
        }

        /** How the home card will look (S3c). */
        fun preview() = ContestService.Contest(
            id = 0, title = title.trim(), body = body, question = question,
            answerType = if (isChoice) "choice" else "text", options = options, prize = prize,
            winnersCount = winnersCount, endsAtText = endsAt.toString(),
        )

        companion object {
            /** Next Sunday 23:59 in Prague, at least two days away. */
            fun defaultEnd(now: Instant = Instant.now()): Instant {
                val zone = ZoneId.of("Europe/Prague")
                val date = now.atZone(zone).toLocalDate().plusDays(2).with(TemporalAdjusters.nextOrSame(DayOfWeek.SUNDAY))
                return date.atTime(LocalTime.of(23, 59)).atZone(zone).toInstant()
            }
        }
    }

    private val _overview = MutableStateFlow<Overview?>(null)
    val overview: StateFlow<Overview?> = _overview.asStateFlow()

    /** Sample data without the server (debug, `ContestDemo`). */
    var demo: Boolean = false

    private suspend fun rpc(name: String, params: JsonObject = buildJsonObject {}) = try {
        supabase.postgrest.rpc(name, params).data
    } catch (e: Exception) {
        throw AccountError.from(e)
    }

    suspend fun reload() {
        if (demo) { _overview.value = ContestDemo.overview(); return }
        _overview.value = ContestService.json.decodeFromString<Overview>(rpc("admin_contests"))
    }

    suspend fun create(draft: Draft) {
        rpc("admin_create_contest", buildJsonObject {
            put("p_title", draft.title)
            put("p_body", draft.body)
            put("p_question", draft.question)
            put("p_answer_type", if (draft.isChoice) "choice" else "text")
            put("p_options", if (draft.isChoice) JsonArray(draft.options.map { JsonPrimitive(it.trim()) }) else JsonNull)
            put("p_correct_option", if (draft.isChoice) JsonPrimitive(draft.correctOption) else JsonNull)
            put("p_prize", draft.prize)
            put("p_winners_count", draft.winnersCount)
            put("p_rules_url", draft.rulesUrl)
            put("p_ends_at", draft.endsAt.toString())
        })
        analytics().track(AnalyticsEvent.AdminContestCreated(if (draft.isChoice) "choice" else "text", draft.winnersCount))
        runCatching { reload() }
        contests.refresh()
    }

    suspend fun end(id: Long) {
        rpc("admin_end_contest", buildJsonObject { put("p_contest_id", id) })
        analytics().track(AnalyticsEvent.AdminContestEnded())
        runCatching { reload() }
        contests.refresh()
    }

    suspend fun detail(id: Long): Detail {
        if (demo) return ContestDemo.detail(drawn = false)
        return Detail.decode(rpc("admin_contest", buildJsonObject { put("p_contest_id", id) }))
    }

    /** [count] null: the contest's number of winners; 1: a replacement. */
    suspend fun draw(id: Long, count: Int? = null): Detail {
        val detail = if (demo) ContestDemo.detail(drawn = true) else Detail.decode(rpc("admin_draw_winners", buildJsonObject {
            put("p_contest_id", id)
            put("p_count", count?.let(::JsonPrimitive) ?: JsonNull)
        }))
        analytics().track(AnalyticsEvent.AdminContestDrawn(replacement = count != null))
        runCatching { reload() }
        return detail
    }

    companion object {
        /** The server's contest codes, else the usual account messages. */
        fun messageRes(e: AccountError): Int = when ((e as? AccountError.Unknown)?.detail) {
            "contest_running" -> cz.slowdownradijo.app.R.string.adminContestRunningError
            "contest_not_ended" -> cz.slowdownradijo.app.R.string.adminContestStillRunning
            "no_entries" -> cz.slowdownradijo.app.R.string.adminContestNoEligible
            else -> e.messageRes
        }
    }
}
