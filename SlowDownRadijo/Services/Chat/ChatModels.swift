import Foundation

/// One row of `chat_messages` (`backend/supabase/sql/020_chat.sql`), as
/// PostgREST and Realtime send it.
struct ChatMessage: Identifiable, Equatable, Decodable {
    enum Role: String, Decodable {
        case listener, supporter, dj, admin
    }

    let id: Int64
    /// `nil` once the author deleted their account.
    let userID: UUID?
    /// The author's current name; `nil` for a deleted account.
    let authorName: String?
    let role: Role
    /// `nil` once a moderator deleted the message.
    let body: String?
    let showID: String?
    let showTitle: String?
    let createdAt: Date
    let deletedAt: Date?
    let pinnedAt: Date?

    var isDeleted: Bool { deletedAt != nil || body == nil }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case authorName = "author_name"
        case role = "author_role"
        case body
        case showID = "show_id"
        case showTitle = "show_title"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case pinnedAt = "pinned_at"
    }

    init(id: Int64, userID: UUID?, authorName: String?, role: Role = .listener, body: String?,
         showID: String? = nil, showTitle: String? = nil, createdAt: Date,
         deletedAt: Date? = nil, pinnedAt: Date? = nil) {
        self.id = id
        self.userID = userID
        self.authorName = authorName
        self.role = role
        self.body = body
        self.showID = showID
        self.showTitle = showTitle
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.pinnedAt = pinnedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        userID = try c.decodeIfPresent(UUID.self, forKey: .userID)
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName)
        role = (try? c.decode(Role.self, forKey: .role)) ?? .listener
        body = try c.decodeIfPresent(String.self, forKey: .body)
        showID = try c.decodeIfPresent(String.self, forKey: .showID)
        showTitle = try c.decodeIfPresent(String.self, forKey: .showTitle)
        // Timestamps come as text from both PostgREST and Realtime, in
        // slightly different shapes ("…T07:04:00.123+00:00", "… 07:04:00+00").
        func date(_ key: CodingKeys) -> Date? {
            (try? c.decodeIfPresent(String.self, forKey: key)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
        }
        createdAt = date(.createdAt) ?? Date()
        deletedAt = date(.deletedAt)
        pinnedAt = date(.pinnedAt)
    }

    static func parseDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        return AccountError.parseDate(text.replacingOccurrences(of: "T", with: " "))
    }

    /// The message is a single emoji ("🔥") — those can merge into "🔥 ×4".
    var singleEmoji: String? {
        guard let body, !isDeleted else { return nil }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count == 1, let character = text.first, character.isChatEmoji else { return nil }
        return text
    }
}

extension Character {
    var isChatEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation
            || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}

/// A message the listener sent that the server hasn't confirmed yet
/// (Figma K: "odesílám…", "Neodesláno · Zkusit znovu").
struct OutgoingChatMessage: Identifiable, Equatable {
    enum Status: Equatable { case sending, failed }

    let id: UUID
    let body: String
    let createdAt: Date
    var status: Status
}

/// What the chat stream draws, worked out from the messages
/// (`docs/chat-concept.md`, "Pravidla předělů"):
///
/// * A divider only before the first message of a day or a show — days and
///   shows nobody wrote in never appear. "Dnes · 07:00 Morning Coffee" when
///   the day changes, "22:00 Noční linka" for the next show that day.
/// * The same emoji sent in a row, each within 60 s of the last, merges into
///   one "🔥 ×4 · nela, marty a 2 další".
/// * Listeners the reader hid are left out.
enum ChatTimeline {
    enum Row: Identifiable, Equatable {
        case divider(id: String, text: String)
        case message(ChatMessage)
        case emoji(id: String, emoji: String, count: Int, names: [String])
        case outgoing(OutgoingChatMessage)

        var id: String {
            switch self {
            case .divider(let id, _): return "d-\(id)"
            case .message(let message): return "m-\(message.id)"
            case .emoji(let id, _, _, _): return "e-\(id)"
            case .outgoing(let message): return "o-\(message.id)"
            }
        }
    }

    /// Names the show for a divider: its start ("07:00") and title.
    struct ShowLabel {
        var start: String?
        var title: String
    }

    static let emojiMergeWindow: TimeInterval = 60

    static var isCzech: Bool { LocalizationManager.shared.language == .cs }

    static func rows(
        messages: [ChatMessage],
        outgoing: [OutgoingChatMessage] = [],
        outgoingShow: (id: String?, title: String?) = (nil, nil),
        hidden: Set<UUID> = [],
        now: Date = Date(),
        calendar: Calendar = ScheduleStore.stationCalendar,
        showLabel: (_ showID: String?, _ title: String?, _ at: Date) -> ShowLabel?
    ) -> [Row] {
        var rows: [Row] = []
        var lastKey: (day: Date, show: String)?
        var group: (first: ChatMessage, last: ChatMessage, emoji: String, count: Int, names: [String])?

        func flushGroup() {
            guard let g = group else { return }
            if g.count == 1 {
                rows.append(.message(g.first))
            } else {
                rows.append(.emoji(id: "\(g.first.id)", emoji: g.emoji, count: g.count, names: g.names))
            }
            group = nil
        }

        func divide(at date: Date, showID: String?, title: String?, id: String) {
            let day = calendar.startOfDay(for: date)
            let show = showID ?? ""
            if let last = lastKey, last.day == day, last.show == show { return }
            flushGroup()
            let dayChanged = lastKey?.day != day
            lastKey = (day, show)
            var parts: [String] = []
            if dayChanged { parts.append(dayLabel(day, now: now, calendar: calendar)) }
            if let label = showLabel(showID, title, date) {
                parts.append([label.start, label.title].compactMap { $0 }.joined(separator: " "))
            } else if showID == nil {
                parts.append(L10n.chatNoShow)
            }
            if !parts.isEmpty {
                rows.append(.divider(id: id, text: parts.joined(separator: " · ")))
            }
        }

        for message in messages where message.userID.map({ !hidden.contains($0) }) ?? true {
            divide(at: message.createdAt, showID: message.showID, title: message.showTitle, id: "\(message.id)")

            if let emoji = message.singleEmoji {
                if var g = group, g.emoji == emoji,
                   message.createdAt.timeIntervalSince(g.last.createdAt) <= emojiMergeWindow {
                    g.last = message
                    g.count += 1
                    let name = message.authorName ?? L10n.deletedAccount
                    if !g.names.contains(name) { g.names.append(name) }
                    group = g
                    continue
                }
                flushGroup()
                group = (message, message, emoji, 1, [message.authorName ?? L10n.deletedAccount])
                continue
            }
            flushGroup()
            rows.append(.message(message))
        }
        flushGroup()

        for message in outgoing {
            divide(at: message.createdAt, showID: outgoingShow.id, title: outgoingShow.title, id: message.id.uuidString)
            rows.append(.outgoing(message))
        }
        return rows
    }

    /// A line of the home page ticker: a message, or the last of a run of
    /// the same emoji ("🔥 ×4").
    struct HomeLine: Identifiable, Equatable {
        let message: ChatMessage
        var count = 1
        var id: Int64 { message.id }
    }

    /// The home page's lines: the same emoji in a row (within 60 s) is one line.
    static func homeLines(_ messages: [ChatMessage]) -> [HomeLine] {
        var lines: [HomeLine] = []
        for message in messages {
            if let emoji = message.singleEmoji, let last = lines.last, last.message.singleEmoji == emoji,
               message.createdAt.timeIntervalSince(last.message.createdAt) <= emojiMergeWindow {
                lines[lines.count - 1] = HomeLine(message: message, count: last.count + 1)
            } else {
                lines.append(HomeLine(message: message))
            }
        }
        return lines
    }

    /// "Dnes", "Včera", "Po 10. 11."
    static func dayLabel(_ day: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        if day == today { return L10n.chatToday }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return L10n.chatYesterday
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: ChatTimeline.isCzech ? "cs_CZ" : "en_GB")
        formatter.setLocalizedDateFormatFromTemplate(ChatTimeline.isCzech ? "EEEEEE d M" : "EEE d MMM")
        let text = formatter.string(from: day)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "nela, marty a 2 další"
    static func names(_ names: [String]) -> String {
        if names.count <= 2 { return names.joined(separator: ChatTimeline.isCzech ? " a " : " and ") }
        return L10n.chatNamesAndMore(names.prefix(2).joined(separator: ", "), names.count - 2)
    }

    /// "Včera 23:41 · Noční linka" — the time line in a message's menu.
    static func timeLine(for message: ChatMessage, now: Date = Date(), calendar: Calendar = ScheduleStore.stationCalendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: ChatTimeline.isCzech ? "cs_CZ" : "en_GB")
        formatter.dateFormat = "H:mm"
        var text = dayLabel(calendar.startOfDay(for: message.createdAt), now: now, calendar: calendar)
            + " " + formatter.string(from: message.createdAt)
        if let title = message.showTitle { text += " · " + title }
        return text
    }
}
