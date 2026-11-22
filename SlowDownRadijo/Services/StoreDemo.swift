import Foundation

#if DEBUG
/// Store screenshots (`AppStoreScreenshotTests`, `-storeDemo YES`): the
/// app as a listener sees it on Monday 16 Nov 2026 at 7:40 in Prague, with
/// Morning Coffee on air, a lively chat, a signed-in Slowrider and a few
/// weeks of listening. Nothing is loaded from or sent to the server for
/// the chat, the account or the stats. Debug builds only.
@MainActor
enum StoreDemo {
    nonisolated static var isOn: Bool { UserDefaults.standard.bool(forKey: "storeDemo") }

    private static var english: Bool { LocalizationManager.shared.language == .en }

    static func apply(stats: ListeningStatsStore) {
        guard isOn else { return }
        AccountService.shared.applyDemo(me: me)
        ChatService.shared.preview(messages: messages, pinned: pinned, lastSeenID: Int64(messages.count))
        stats.applyDemo(snapshot: snapshot, publicStats: PublicStats(available: true, communitySeconds: 1_238_424 * 3600, rankedListeners: 1284))
    }

    // MARK: Profil

    static var me: AccountService.Me {
        var me = AccountService.Me(userID: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!, nickname: "cevapcicidisko")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
        me.registeredAt = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))
        me.chatMessagesCount = 48
        me.voiceMessagesCount = 3
        // `-contestDemo admin`: the contest admin pages in Profil.
        if UserDefaults.standard.string(forKey: "contestDemo") == "admin" { me.isAdmin = true }
        return me
    }

    // MARK: Chat (Morning Coffee, Monday morning)

    private static let morningCoffee = "morning-coffee-s-dj-pufaz"
    private static let pufaz = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!

    private static func message(_ id: Int64, _ name: String, _ body: String, minutesAgo: Double, role: ChatMessage.Role = .listener, user: UUID? = nil, pinned: Bool = false) -> ChatMessage {
        let at = AppClock.now.addingTimeInterval(-minutesAgo * 60)
        return ChatMessage(
            id: id,
            userID: user ?? UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            authorName: name,
            role: role,
            body: body,
            showID: morningCoffee,
            showTitle: "Morning Coffee",
            createdAt: at,
            deletedAt: nil,
            pinnedAt: pinned ? at : nil
        )
    }

    static var pinned: ChatMessage {
        message(1, "DJ Pufaz", english ? "Good morning! What are you listening to over coffee? ☕" : "Dobré ráno! Co dnes posloucháte u kafe? ☕",
                minutesAgo: 38, role: .dj, user: pufaz, pinned: true)
    }

    static var messages: [ChatMessage] {
        let e = english
        return [
            pinned,
            message(2, "kafe_s_mlekem", e ? "Good morning from tram number 9 🚋" : "Dobré ráno z tramvaje číslo 9 🚋", minutesAgo: 12),
            message(3, "cevapcicidisko", e ? "That intro woke me up better than an espresso" : "Ten úvod mě probudil líp než espresso", minutesAgo: 10, user: me.userID),
            message(4, "DJ Pufaz", e ? "Thanks! Something by Khruangbin is coming up, stay tuned 🙌" : "Díky! Za chvíli přijde něco od Khruangbin, vydržte 🙌", minutesAgo: 9, role: .dj, user: pufaz),
            message(5, "jana_z_letne", e ? "Hello to the whole office in Smíchov ☀️" : "Pozdrav celé kanceláři na Smíchově ☀️", minutesAgo: 7),
            message(6, "nela", "🔥", minutesAgo: 5.0),
            message(7, "marty", "🔥", minutesAgo: 4.8),
            message(8, "ondra_b", "🔥", minutesAgo: 4.7),
            message(9, "kafe_s_mlekem", "🔥", minutesAgo: 4.6),
            message(10, "groove_petr", e ? "Could I ask for something by Erykah Badu? 🙏" : "Můžu poprosit o něco od Erykah Badu? 🙏", minutesAgo: 2),
        ]
    }

    // MARK: Statistiky

    static var snapshot: StatsSnapshot {
        let today = AppClock.now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
        // The last seven days, oldest first: Tuesday … Monday morning.
        let minutes = [60, 95, 40, 120, 75, 150, 40]
        var daily: [StatsSnapshot.Row] = []
        for (index, value) in minutes.enumerated() {
            let date = calendar.date(byAdding: .day, value: index - 6, to: today)!
            daily.append(.init(day: ListeningTracker.dayString(for: date), showId: index == 6 ? morningCoffee : "beat-brunch-s-jaro-cossiga", seconds: value * 60))
        }
        let shows: [StatsSnapshot.ShowTotal] = [
            .init(showId: morningCoffee, seconds: 32 * 3600),
            .init(showId: "beat-brunch-s-jaro-cossiga", seconds: 21 * 3600),
            .init(showId: "diggin-time-s-dj-magic", seconds: 14 * 3600),
            .init(showId: "weekend-aftertaste-s-cube-positive", seconds: 9 * 3600),
            .init(showId: "africa-incorporated-s-chuck-diesal", seconds: 6 * 3600),
        ]
        return StatsSnapshot(
            available: true,
            totalSeconds: 310_440,
            communitySeconds: 1_238_424 * 3600,
            rankedListeners: 1284,
            rank: 12,
            daily: daily,
            shows: shows,
            aheadSeconds: 310_440 + 88 * 60,
            behindSeconds: 310_440 - 5 * 3600 - 32 * 60,
            listeningDays: 41
        )
    }
}
#endif
