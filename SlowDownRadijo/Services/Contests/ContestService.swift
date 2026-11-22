import Foundation
import Supabase

/// The contest on the home screen (Figma "Soutěže" H1–H3, D1–D9):
/// backend/supabase/sql/028_contests.sql, `contest_current`, `contest_enter`,
/// `contest_dismiss`.
///
/// Everyone sees the running contest; only registered Slowriders can enter.
/// Closing the card is remembered on the phone at once (so it stays away
/// offline and without any session) and on the server when the phone has a
/// session, so it stays away on the listener's other phones too.
///
/// Mirrors `android/.../contests/ContestService.kt`.
@MainActor
final class ContestService: ObservableObject {
    static let shared = ContestService()

    struct Entry: Decodable, Equatable {
        let answer: String
        let phone: String?
        let createdAt: Date?

        enum CodingKeys: String, CodingKey { case answer, phone, createdAt = "created_at" }

        init(answer: String, phone: String?, createdAt: Date?) {
            self.answer = answer
            self.phone = phone
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            answer = try c.decode(String.self, forKey: .answer)
            phone = try? c.decodeIfPresent(String.self, forKey: .phone)
            createdAt = (try? c.decodeIfPresent(String.self, forKey: .createdAt)).flatMap { $0 }.flatMap(ContestService.parseDate)
        }
    }

    struct Contest: Decodable, Identifiable, Equatable {
        enum AnswerType: String, Decodable { case choice, text }
        enum MyStatus: String, Decodable { case entered, dismissed }

        let id: Int64
        let title: String
        let body: String
        let question: String
        let answerType: AnswerType
        let options: [String]
        let prize: String
        let winnersCount: Int
        let rulesURL: URL?
        let endsAt: Date
        var myStatus: MyStatus?
        var myEntry: Entry?

        enum CodingKeys: String, CodingKey {
            case id, title, body, question, options, prize
            case answerType = "answer_type", winnersCount = "winners_count", rulesURL = "rules_url"
            case endsAt = "ends_at", myStatus = "my_status", myEntry = "my_entry"
        }

        init(id: Int64, title: String, body: String, question: String, answerType: AnswerType, options: [String],
             prize: String, winnersCount: Int, rulesURL: URL?, endsAt: Date, myStatus: MyStatus? = nil, myEntry: Entry? = nil) {
            self.id = id
            self.title = title
            self.body = body
            self.question = question
            self.answerType = answerType
            self.options = options
            self.prize = prize
            self.winnersCount = winnersCount
            self.rulesURL = rulesURL
            self.endsAt = endsAt
            self.myStatus = myStatus
            self.myEntry = myEntry
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int64.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            body = try c.decode(String.self, forKey: .body)
            question = try c.decode(String.self, forKey: .question)
            answerType = (try? c.decode(AnswerType.self, forKey: .answerType)) ?? .text
            options = (try? c.decodeIfPresent([String].self, forKey: .options)) ?? []
            prize = (try? c.decode(String.self, forKey: .prize)) ?? ""
            winnersCount = (try? c.decode(Int.self, forKey: .winnersCount)) ?? 1
            rulesURL = (try? c.decodeIfPresent(String.self, forKey: .rulesURL)).flatMap { $0 }.flatMap(URL.init(string:))
            endsAt = (try? c.decode(String.self, forKey: .endsAt)).flatMap(ContestService.parseDate) ?? .distantFuture
            myStatus = try? c.decodeIfPresent(MyStatus.self, forKey: .myStatus)
            myEntry = try? c.decodeIfPresent(Entry.self, forKey: .myEntry)
        }

        var isRunning: Bool { endsAt > Date() }

        /// "A · Weekend Aftertaste" for a letter answer, else the words.
        func answerLabel(_ answer: String) -> String {
            guard answerType == .choice, let index = ["A", "B", "C"].firstIndex(of: answer), options.indices.contains(index) else { return answer }
            return "\(answer) · \(options[index])"
        }
    }

    enum Failure: Error, Equatable {
        case closed, alreadyEntered, answerInvalid, phoneInvalid, accountRequired, offline, other
    }

    @Published private(set) var current: Contest?

    private static let dismissedKey = "contests.dismissed"
    private var dismissedLocally: Set<Int64> {
        get { Set((UserDefaults.standard.array(forKey: Self.dismissedKey) as? [Int64]) ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(50)), forKey: Self.dismissedKey) }
    }
    private var shownThisLaunch: Set<Int64> = []
    /// Hides the card the moment the contest ends, even with the app open.
    private var endWatch: Task<Void, Never>?

    private var client: SupabaseClient { AppSupabase.client }

    private init() {}

    /// The home card shows: a running contest the listener hasn't entered
    /// or closed.
    var infoboxContest: Contest? {
        guard let current, current.isRunning, current.myStatus == nil, !dismissedLocally.contains(current.id) else { return nil }
        return current
    }

    func refresh() async {
        #if DEBUG
        if ContestDemo.mode != nil {
            if current == nil { current = ContestDemo.contest }
            return
        }
        #endif
        do {
            // A session's token rides along when there is one; without one
            // the publishable key is enough (`contest_current` is public).
            _ = try? await SupabaseSession.accessToken(creatingAnonymous: false)
            let contest: Contest? = try await client.rpc("contest_current").execute().value
            current = contest
            endWatch?.cancel()
            if let end = contest?.endsAt, end > Date(), end.timeIntervalSinceNow < 7 * 24 * 3600 {
                endWatch = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow + 1))
                    guard !Task.isCancelled else { return }
                    self?.objectWillChange.send()
                    await self?.refresh()
                }
            }
        } catch {
            // Offline: keep what we had.
        }
    }

    func infoboxShown(_ contest: Contest) {
        guard !shownThisLaunch.contains(contest.id) else { return }
        shownThisLaunch.insert(contest.id)
        Analytics.shared.track(.contestInfoboxShown(contestID: contest.id))
    }

    /// "Zavřít a nesoutěžit" (H2).
    func dismiss(_ contest: Contest) {
        dismissedLocally.insert(contest.id)
        objectWillChange.send()
        Analytics.shared.track(.contestInfoboxDismissed(contestID: contest.id))
        Task {
            #if DEBUG
            if ContestDemo.mode != nil { return }
            #endif
            guard (try? await SupabaseSession.accessToken(creatingAnonymous: false)) != nil else { return }
            _ = try? await client.rpc("contest_dismiss", params: ["p_contest_id": contest.id]).execute()
        }
    }

    func enter(_ contest: Contest, answer: String, phone: String) async throws -> Entry {
        struct Params: Encodable { let p_contest_id: Int64; let p_answer: String; let p_phone: String }
        #if DEBUG
        if ContestDemo.mode != nil {
            try await Task.sleep(for: .seconds(1))
            guard let phone = Self.normalizedPhone(phone) else { throw Failure.phoneInvalid }
            let entry = Entry(answer: answer, phone: phone, createdAt: Date())
            current?.myStatus = .entered
            current?.myEntry = entry
            return entry
        }
        #endif
        do {
            let entry: Entry = try await client.rpc(
                "contest_enter",
                params: Params(p_contest_id: contest.id, p_answer: answer, p_phone: phone)
            ).execute().value
            if current?.id == contest.id {
                current?.myStatus = .entered
                current?.myEntry = entry
            }
            Analytics.shared.track(.contestEntrySubmitted(contestID: contest.id, answerType: contest.answerType.rawValue, success: true, error: nil))
            return entry
        } catch {
            let failure = Self.failure(error)
            Analytics.shared.track(.contestEntrySubmitted(contestID: contest.id, answerType: contest.answerType.rawValue, success: false, error: "\(failure)"))
            if failure == .alreadyEntered || failure == .closed { await refresh() }
            throw failure
        }
    }

    /// `timestamptz` inside JSON: "2026-11-30T23:59:00+01:00", with 0–6
    /// fraction digits.
    nonisolated static func parseDate(_ text: String) -> Date? {
        var normalized = text.replacingOccurrences(of: " ", with: "T")
        if let dot = normalized.firstIndex(of: "."),
           let zone = normalized[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraction = normalized[normalized.index(after: dot)..<zone]
            let millis = String((fraction + "000").prefix(3))
            normalized.replaceSubrange(dot..<zone, with: "." + millis)
        }
        if normalized.range(of: #"[+-]\d{2}$"#, options: .regularExpression) != nil { normalized += ":00" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: normalized) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: normalized)
    }

    static func failure(_ error: Error) -> Failure {
        switch AccountError.from(error) {
        case .offline: return .offline
        case .accountRequired, .notSignedIn: return .accountRequired
        case .unknown(let code):
            switch code {
            case "contest_closed": return .closed
            case "already_entered": return .alreadyEntered
            case "answer_invalid": return .answerInvalid
            case "phone_invalid": return .phoneInvalid
            default: return .other
            }
        default: return .other
        }
    }

    /// The same rules as `contest_normalize_phone`: a Czech number with or
    /// without +420 / 00420, or any number with its country code.
    static func normalizedPhone(_ raw: String) -> String? {
        var s = raw.filter { !" -()./\u{00A0}".contains($0) }
        if s.hasPrefix("00"), s.dropFirst(2).allSatisfy(\.isASCIIDigit) { s = "+" + s.dropFirst(2) }
        if s.count == 9, s.allSatisfy(\.isASCIIDigit) { s = "+420" + s }
        guard s.hasPrefix("+"), s.dropFirst().allSatisfy(\.isASCIIDigit) else { return nil }
        let digits = s.dropFirst()
        if digits.hasPrefix("420") { return digits.count == 12 ? s : nil }
        guard let first = digits.first, first != "0", (8...15).contains(digits.count) else { return nil }
        return s
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// Dates on the contest screens, in the station's time zone.
enum ContestFormat {
    /// "neděle 30. 11., 23:59" / "Sunday 30 Nov, 23:59".
    static func dayAndTime(_ date: Date) -> String {
        format(date, cs: "EEEE d. M., H:mm", en: "EEEE d MMM, HH:mm")
    }

    /// "30. 11." / "30 Nov".
    static func day(_ date: Date) -> String {
        format(date, cs: "d. M.", en: "d MMM")
    }

    /// "30. 11. v 8:14" / "30 Nov, 08:14".
    static func dayTimeShort(_ date: Date) -> String {
        format(date, cs: "d. M. 'v' H:mm", en: "d MMM, HH:mm")
    }

    /// "+420777123456" → "+420 777 123 456"; other numbers as they are.
    static func phone(_ phone: String) -> String {
        guard phone.hasPrefix("+420"), phone.count == 13 else { return phone }
        let d = Array(phone.dropFirst(4))
        return "+420 \(String(d[0..<3])) \(String(d[3..<6])) \(String(d[6..<9]))"
    }

    private static func format(_ date: Date, cs: String, en: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ScheduleStore.stationCalendar.timeZone
        formatter.locale = Locale(identifier: L10n.isEnglish ? "en_GB" : "cs_CZ")
        formatter.dateFormat = L10n.isEnglish ? en : cs
        return formatter.string(from: date)
    }
}
