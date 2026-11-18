import SwiftUI

/// How a role shows in the chat (Figma "Chat/Zpráva"): only the name's
/// colour changes — listener `mutedText`, supporter `gold` + ★, DJ and
/// admin `liveRed` (DJ also with its "DJ" tag).
enum ChatStyle {
    static func nameColor(_ role: ChatMessage.Role) -> Color {
        switch role {
        case .listener: return Theme.mutedText
        case .supporter: return Theme.gold
        case .dj, .admin: return Theme.liveRed
        }
    }

    static func name(_ message: ChatMessage) -> String {
        message.authorName ?? L10n.deletedAccount
    }

    static let quickEmoji = ["🔥", "❤️", "😂", "🎵", "👏", "💜", "🎧"]

    static let pickerEmoji = [
        "😀", "😂", "🥲", "😍", "😎", "🤩", "🥳", "😴",
        "🤔", "😮", "😢", "😡", "🙏", "👏", "🙌", "👋",
        "👍", "👎", "💪", "🤘", "✌️", "🫶", "❤️", "💜",
        "🔥", "✨", "🎵", "🎶", "🎧", "🎙️", "📻", "💿",
        "☕️", "🍺", "🍷", "🌙", "☀️", "🌧️", "🌊", "🌿",
    ]
}

/// "DJ" next to a host's name.
struct ChatDJTag: View {
    var body: some View {
        Text("DJ")
            .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
            .foregroundStyle(Theme.liveRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Theme.liveRed.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// The author line of a message in the chat sheet.
struct ChatAuthorLine: View {
    let name: String
    let role: ChatMessage.Role

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                .foregroundStyle(ChatStyle.nameColor(role))
                .lineLimit(1)
            if role == .supporter {
                Text("★")
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.gold)
            }
            if role == .dj {
                ChatDJTag()
            }
        }
    }
}

/// One message in the chat sheet: the name above the text, no time (the
/// dividers say when; the exact time is in the menu).
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ChatAuthorLine(name: ChatStyle.name(message), role: message.role)
            if message.isDeleted {
                Text(L10n.chatDeletedByModerator)
                    .font(Theme.Typography.Copy.reading.italic())
                    .foregroundStyle(Theme.subtleText)
            } else {
                Text(message.body ?? "")
                    .font(Theme.Typography.Copy.reading)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.disabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "🔥 ×4  nela, marty a 2 další"
struct ChatEmojiGroupRow: View {
    let emoji: String
    let count: Int
    let names: [String]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(emoji)
                .font(.system(size: 20))
            Text("×\(count)")
                .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.textPrimary)
            Text(ChatTimeline.names(names))
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "—— Dnes · 07:00 Morning Coffee ——"
struct ChatDividerRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(text)
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(Theme.subtleText)
                .lineLimit(1)
                .layoutPriority(1)
            line
        }
        .padding(.vertical, 2)
        .accessibilityAddTraits(.isHeader)
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.subtleText.opacity(0.3))
            .frame(height: 1)
            .frame(minWidth: 12)
    }
}

/// The listener's own message before the server confirmed it.
struct ChatOutgoingRow: View {
    let message: OutgoingChatMessage
    let name: String
    let role: ChatMessage.Role
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ChatAuthorLine(name: name, role: role)
            Text(message.body)
                .font(Theme.Typography.Copy.reading)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            switch message.status {
            case .sending:
                Text(L10n.chatSending)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            case .failed:
                Button(action: onRetry) {
                    Text("\(L10n.chatNotSent) · \(L10n.chatRetry)")
                        .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.liveRed)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(message.status == .sending ? 0.6 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
