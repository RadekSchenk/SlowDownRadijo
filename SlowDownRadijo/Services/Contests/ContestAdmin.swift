import Foundation
import Supabase

/// Profil ▸ Správa ▸ Soutěže for admins and the superadmin (Figma
/// "Soutěže" S1–S6): backend/supabase/sql/028_contests.sql, `admin_contests`,
/// `admin_create_contest`, `admin_end_contest`, `admin_contest`,
/// `admin_draw_winners`.
///
/// Mirrors `android/.../contests/ContestAdmin.kt`.
@MainActor
final class ContestAdmin: ObservableObject {
    static let shared = ContestAdmin()

    struct Summary: Decodable, Identifiable, Equatable, Hashable {
        let id: Int64
        let title: String
        let answerType: String
        let prize: String
        let winnersCount: Int
        let startsAt: Date?
        let endsAt: Date?
        let endedAt: Date?
        let endedEarly: Bool
        let drawnAt: Date?
        let isRunning: Bool
        let entries: Int
        let correct: Int
        let dismissed: Int
        let winners: Int

        enum CodingKeys: String, CodingKey {
            case id, title, prize, entries, correct, dismissed, winners
            case answerType = "answer_type", winnersCount = "winners_count", startsAt = "starts_at", endsAt = "ends_at"
            case endedAt = "ended_at", endedEarly = "ended_early", drawnAt = "drawn_at", isRunning = "is_running"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func date(_ key: CodingKeys) -> Date? {
                (try? c.decodeIfPresent(String.self, forKey: key)).flatMap { $0 }.flatMap(ContestService.parseDate)
            }
            id = try c.decode(Int64.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            answerType = (try? c.decode(String.self, forKey: .answerType)) ?? "choice"
            prize = (try? c.decode(String.self, forKey: .prize)) ?? ""
            winnersCount = (try? c.decode(Int.self, forKey: .winnersCount)) ?? 1
            startsAt = date(.startsAt)
            endsAt = date(.endsAt)
            endedAt = date(.endedAt)
            endedEarly = (try? c.decode(Bool.self, forKey: .endedEarly)) ?? false
            drawnAt = date(.drawnAt)
            isRunning = (try? c.decode(Bool.self, forKey: .isRunning)) ?? false
            entries = (try? c.decode(Int.self, forKey: .entries)) ?? 0
            correct = (try? c.decode(Int.self, forKey: .correct)) ?? 0
            dismissed = (try? c.decode(Int.self, forKey: .dismissed)) ?? 0
            winners = (try? c.decode(Int.self, forKey: .winners)) ?? 0
        }

        /// When it stopped taking answers.
        var endTime: Date? { endedAt ?? endsAt }
    }

    struct Overview: Decodable, Equatable {
        let current: Summary?
        let previous: [Summary]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            current = try? c.decodeIfPresent(Summary.self, forKey: .current)
            previous = (try? c.decode([Summary].self, forKey: .previous)) ?? []
        }

        enum CodingKeys: String, CodingKey { case current, previous }
    }

    struct Person: Decodable, Equatable, Identifiable {
        let id = UUID()
        let nickname: String?
        let answer: String?
        let isCorrect: Bool?
        let phone: String?
        let at: Date?

        enum CodingKeys: String, CodingKey { case nickname, answer, isCorrect = "is_correct", phone, createdAt = "created_at", drawnAt = "drawn_at" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            nickname = try? c.decodeIfPresent(String.self, forKey: .nickname)
            answer = try? c.decodeIfPresent(String.self, forKey: .answer)
            isCorrect = try? c.decodeIfPresent(Bool.self, forKey: .isCorrect)
            phone = try? c.decodeIfPresent(String.self, forKey: .phone)
            let raw = (try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? (try? c.decodeIfPresent(String.self, forKey: .drawnAt))
            at = raw.flatMap { $0 }.flatMap(ContestService.parseDate)
        }

        static func == (lhs: Person, rhs: Person) -> Bool {
            lhs.nickname == rhs.nickname && lhs.answer == rhs.answer && lhs.phone == rhs.phone && lhs.at == rhs.at
        }
    }

    struct Detail: Decodable, Equatable {
        let summary: Summary
        let question: String
        let options: [String]
        let correctOption: Int?
        let distribution: [String: Int]
        let entries: [Person]
        let winners: [Person]

        enum CodingKeys: String, CodingKey { case question, options, correctOption = "correct_option", distribution, entryList = "entry_list", winnersList = "winners_list" }
        private struct Bucket: Decodable { let answer: String; let count: Int }

        init(from decoder: Decoder) throws {
            summary = try Summary(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            question = (try? c.decode(String.self, forKey: .question)) ?? ""
            options = (try? c.decodeIfPresent([String].self, forKey: .options)) ?? []
            correctOption = try? c.decodeIfPresent(Int.self, forKey: .correctOption)
            let buckets = (try? c.decode([Bucket].self, forKey: .distribution)) ?? []
            distribution = Dictionary(buckets.map { ($0.answer, $0.count) }, uniquingKeysWith: +)
            entries = (try? c.decode([Person].self, forKey: .entryList)) ?? []
            winners = (try? c.decode([Person].self, forKey: .winnersList)) ?? []
        }

        func answerLabel(_ answer: String?) -> String {
            guard let answer else { return "" }
            guard summary.answerType == "choice", let index = ["A", "B", "C"].firstIndex(of: answer), options.indices.contains(index) else { return answer }
            return "\(answer) · \(options[index])"
        }

        /// The answers as CSV, for handing over the prizes.
        var csv: String {
            func cell(_ text: String?) -> String { "\"\((text ?? "").replacingOccurrences(of: "\"", with: "\"\""))\"" }
            let iso = ISO8601DateFormatter()
            var lines = ["nickname,answer,correct,phone,sent_at,winner"]
            let winnerNames = Set(winners.compactMap(\.nickname))
            for e in entries {
                lines.append([cell(e.nickname), cell(answerLabel(e.answer)), e.isCorrect.map { $0 ? "yes" : "no" } ?? "",
                              cell(e.phone), e.at.map(iso.string(from:)) ?? "", winnerNames.contains(e.nickname ?? "") ? "yes" : ""].joined(separator: ","))
            }
            return lines.joined(separator: "\n")
        }
    }

    /// What S3 sends.
    struct Draft: Equatable {
        var title = ""
        var body = ""
        var question = ""
        var isChoice = true
        var options = ["", "", ""]
        var correctOption: Int? = nil
        var prize = ""
        var winnersCount = 1
        var rulesURL = ""
        var endsAt = Draft.defaultEnd()

        /// Next Sunday 23:59, at least two days away.
        static func defaultEnd(now: Date = Date()) -> Date {
            var calendar = ScheduleStore.stationCalendar
            calendar.firstWeekday = 2
            var date = calendar.date(byAdding: .day, value: 2, to: now) ?? now
            while calendar.component(.weekday, from: date) != 1 {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date
        }

        enum Field: String { case title, body, question, options, prize, winnersCount = "winners_count", rulesURL = "rules_url", endsAt = "ends_at" }

        /// The same checks as `admin_create_contest`, so the form shows them
        /// before sending.
        func problems(now: Date = Date()) -> Set<Field> {
            var result = Set<Field>()
            func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
            if !(3...60).contains(trimmed(title).count) { result.insert(.title) }
            if !(10...3000).contains(trimmed(body).count) { result.insert(.body) }
            if !(5...200).contains(trimmed(question).count) { result.insert(.question) }
            if isChoice, options.contains(where: { !(1...80).contains(trimmed($0).count) }) || correctOption == nil { result.insert(.options) }
            if !(2...40).contains(trimmed(prize).count) { result.insert(.prize) }
            if !(1...20).contains(winnersCount) { result.insert(.winnersCount) }
            if trimmed(rulesURL).range(of: #"^(https?://)?[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/\S*)?$"#, options: .regularExpression) == nil { result.insert(.rulesURL) }
            if endsAt <= now.addingTimeInterval(10 * 60) { result.insert(.endsAt) }
            return result
        }

        /// How the home card will look (S3c).
        var preview: ContestService.Contest {
            ContestService.Contest(id: 0, title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: body, question: question,
                                   answerType: isChoice ? .choice : .text, options: options, prize: prize,
                                   winnersCount: winnersCount, rulesURL: nil, endsAt: endsAt)
        }
    }

    @Published private(set) var overview: Overview?

    private var client: SupabaseClient { AppSupabase.client }

    private init() {}

    func reload() async throws {
        #if DEBUG
        if ContestDemo.mode != nil { overview = ContestDemo.overview; return }
        #endif
        overview = try await call { try await self.client.rpc("admin_contests").execute().value }
    }

    func create(_ draft: Draft) async throws {
        struct Params: Encodable {
            let p_title, p_body, p_question, p_answer_type: String
            let p_options: [String]?
            let p_correct_option: Int?
            let p_prize: String
            let p_winners_count: Int
            let p_rules_url: String
            let p_ends_at: String
        }
        let params = Params(
            p_title: draft.title, p_body: draft.body, p_question: draft.question,
            p_answer_type: draft.isChoice ? "choice" : "text",
            p_options: draft.isChoice ? draft.options.map { $0.trimmingCharacters(in: .whitespaces) } : nil,
            p_correct_option: draft.isChoice ? draft.correctOption : nil,
            p_prize: draft.prize, p_winners_count: draft.winnersCount, p_rules_url: draft.rulesURL,
            p_ends_at: ISO8601DateFormatter().string(from: draft.endsAt)
        )
        let _: Summary = try await call { try await self.client.rpc("admin_create_contest", params: params).execute().value }
        Analytics.shared.track(.adminContestCreated(answerType: params.p_answer_type, winners: draft.winnersCount))
        try? await reload()
        await ContestService.shared.refresh()
    }

    func end(_ id: Int64) async throws {
        let _: Summary = try await call { try await self.client.rpc("admin_end_contest", params: ["p_contest_id": id]).execute().value }
        Analytics.shared.track(.adminContestEnded)
        try? await reload()
        await ContestService.shared.refresh()
    }

    func detail(_ id: Int64) async throws -> Detail {
        #if DEBUG
        if ContestDemo.mode != nil { return ContestDemo.detail(drawn: false) }
        #endif
        return try await call { try await self.client.rpc("admin_contest", params: ["p_contest_id": id]).execute().value }
    }

    /// `count` nil: the contest's number of winners; 1: a replacement.
    func draw(_ id: Int64, count: Int? = nil) async throws -> Detail {
        struct Params: Encodable { let p_contest_id: Int64; let p_count: Int? }
        #if DEBUG
        if ContestDemo.mode != nil { return ContestDemo.detail(drawn: true) }
        #endif
        let detail: Detail = try await call {
            try await self.client.rpc("admin_draw_winners", params: Params(p_contest_id: id, p_count: count)).execute().value
        }
        Analytics.shared.track(.adminContestDrawn(replacement: count != nil))
        try? await reload()
        return detail
    }

    /// Server code → a line for the toast.
    static func message(for error: Error) -> String {
        if case .unknown(let code) = AccountError.from(error) {
            switch code {
            case "contest_running": return L10n.adminContestRunningError
            case "contest_not_ended": return L10n.adminContestStillRunning
            case "no_entries": return L10n.adminContestNoEligible
            default: break
            }
        }
        return AccountError.from(error).userMessage
    }

    private func call<T>(_ work: @escaping () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            throw error is AccountError ? error : AccountError.from(error)
        }
    }
}
