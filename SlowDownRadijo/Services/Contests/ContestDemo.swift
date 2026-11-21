import Foundation

#if DEBUG
/// A sample contest without the server, for screenshots and trying the
/// screens in the simulator (`-contestDemo YES`, or `entered`). With
/// `-storeDemo YES` the listener is also a signed-in admin. Debug builds only.
@MainActor
enum ContestDemo {
    static var mode: String? {
        guard let value = UserDefaults.standard.string(forKey: "contestDemo"), !value.isEmpty, value != "NO" else { return nil }
        return value
    }

    private static var english: Bool { LocalizationManager.shared.language == .en }

    static var contest: ContestService.Contest {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
        let now = AppClock.now
        var end = calendar.date(byAdding: .day, value: 6, to: now) ?? now
        end = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: end) ?? end
        var contest = ContestService.Contest(
            id: 1,
            title: english ? "Win Thundercat – Distracted on vinyl" : "Vyhraj vinyl Thundercat – Distracted",
            body: english
                ? "Another contest for our Slowriders: Distracted on vinyl, Thundercat's fifth and latest album, with guests including Tame Impala, Mac Miller, Lil Yachty and Flying Lotus. Answer the question and leave your phone number. We draw the winner on the Monday after the contest, live on Morning Coffee between 7 and 9."
                : "Pro naše Slowriders tu máme další soutěž: vinyl Distracted, páté a nejnovější album Thundercata. Na desce hostují Tame Impala, Mac Miller, Lil Yachty, Flying Lotus a další. Odpověz na otázku a nech nám telefon. Výherce vylosujeme v pondělí po skončení soutěže v Morning Coffee mezi 7. a 9. hodinou.",
            question: english ? "Which producer and long-time Thundercat collaborator guests on Distracted?" : "Který producent a dlouholetý spolupracovník Thundercata hostuje na albu Distracted?",
            answerType: .choice,
            options: ["Moby", "Flying Lotus", "Fatboy Slim"],
            prize: english ? "Distracted on vinyl" : "Vinyl Distracted",
            winnersCount: 1,
            rulesURL: URL(string: "https://slowdownradijo.cz/pravidla-soutezi/"),
            endsAt: end
        )
        if mode == "entered" {
            contest.myStatus = .entered
            contest.myEntry = .init(answer: "B", phone: "+420777123456", createdAt: now.addingTimeInterval(-3600 * 26))
        }
        return contest
    }

    // MARK: Správa ▸ Soutěže

    private static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    static var overview: ContestAdmin.Overview {
        let now = Date()
        let c = contest
        let json = """
        {"current": {"id": 1, "title": "\(c.title)", "answer_type": "choice", "prize": "\(c.prize)", "winners_count": 1,
          "starts_at": "\(iso(now.addingTimeInterval(-3 * 86400)))", "ends_at": "\(iso(c.endsAt))", "ended_at": null,
          "ended_early": false, "drawn_at": null, "is_running": true, "entries": 128, "correct": 97, "dismissed": 41, "winners": 0},
         "previous": [
          {"id": 2, "title": "Vinyl Khruangbin – A LA SALA", "answer_type": "text", "prize": "Vinyl", "winners_count": 1,
           "starts_at": "\(iso(now.addingTimeInterval(-30 * 86400)))", "ends_at": "\(iso(now.addingTimeInterval(-19 * 86400)))",
           "ended_at": null, "ended_early": false, "drawn_at": "\(iso(now.addingTimeInterval(-18 * 86400)))", "is_running": false,
           "entries": 214, "correct": 0, "dismissed": 12, "winners": 1},
          {"id": 3, "title": "Lístky na Prague Sound Days", "answer_type": "choice", "prize": "2× lístky", "winners_count": 1,
           "starts_at": "\(iso(now.addingTimeInterval(-50 * 86400)))", "ends_at": "\(iso(now.addingTimeInterval(-40 * 86400)))",
           "ended_at": null, "ended_early": false, "drawn_at": null, "is_running": false,
           "entries": 156, "correct": 120, "dismissed": 30, "winners": 0}]}
        """
        return try! JSONDecoder().decode(ContestAdmin.Overview.self, from: Data(json.utf8))
    }

    static func detail(drawn: Bool) -> ContestAdmin.Detail {
        let now = Date()
        let c = contest
        let winners = drawn ? """
        [{"nickname": "vinylovy_tom", "phone": "+420777123456", "answer": "B", "drawn_at": "\(iso(now))"}]
        """ : "[]"
        let json = """
        {"id": 3, "title": "\(c.title)", "answer_type": "choice", "prize": "\(c.prize)", "winners_count": 1,
         "starts_at": "\(iso(now.addingTimeInterval(-9 * 86400)))", "ends_at": "\(iso(now.addingTimeInterval(-2 * 86400)))",
         "ended_at": null, "ended_early": false, "drawn_at": \(drawn ? "\"\(iso(now))\"" : "null"), "is_running": false,
         "entries": 342, "correct": 261, "dismissed": 41, "winners": \(drawn ? 1 : 0),
         "question": "\(c.question)", "options": ["Moby", "Flying Lotus", "Fatboy Slim"], "correct_option": 1,
         "distribution": [{"answer": "A", "count": 51}, {"answer": "B", "count": 261}, {"answer": "C", "count": 30}],
         "entry_list": [
          {"nickname": "vinylovy_tom", "answer": "B", "is_correct": true, "phone": "+420777123456", "created_at": "\(iso(now.addingTimeInterval(-50 * 3600)))"},
          {"nickname": "kafe_s_mlekem", "answer": "A", "is_correct": false, "phone": "+420604555210", "created_at": "\(iso(now.addingTimeInterval(-53 * 3600)))"},
          {"nickname": "jana_z_letne", "answer": "B", "is_correct": true, "phone": "+420731908117", "created_at": "\(iso(now.addingTimeInterval(-80 * 3600)))"}],
         "winners_list": \(winners)}
        """
        return try! JSONDecoder().decode(ContestAdmin.Detail.self, from: Data(json.utf8))
    }
}
#endif
