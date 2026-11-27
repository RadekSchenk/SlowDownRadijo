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

    /// The curved line from a quote to the replier's name.
    static let spine = Color(hex: 0x5A507C)

    static let quickEmoji = ["🔥", "❤️", "😂", "🎵", "👏", "💜", "🎧"]

    static let pickerEmoji = [
        "😀", "😂", "🥲", "😍", "😎", "🤩", "🥳", "😴",
        "🤔", "😮", "😢", "😡", "🙏", "👏", "🙌", "👋",
        "👍", "👎", "💪", "🤘", "✌️", "🫶", "❤️", "💜",
        "🔥", "✨", "🎵", "🎶", "🎧", "🎙️", "📻", "💿",
        "☕️", "🍺", "🍷", "🌙", "☀️", "🌧️", "🌊", "🌿",
    ]
}

/// "Moderátor" next to a host's name.
struct ChatHostTag: View {
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        Text(L10n.chatHostBadge)
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
                ChatHostTag()
            }
        }
    }
}

/// One message in the chat sheet: the name above the text, no time (the
/// dividers say when; the exact time is in the menu). A reply has its quote
/// above the name (Figma "Chat/Zpráva s odpovědí").
struct ChatMessageRow: View {
    let message: ChatMessage
    var quote: ChatQuote.Display? = nil
    var onQuoteTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quote {
                ChatQuoteLine(display: quote, onTap: onQuoteTap)
                    .padding(.bottom, -2)
            }
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

/// The quote above a reply (Figma "Chat/Citace", variant A): one line,
/// "karolina.pivnivila · Výsadba nové chmelnice…", and a thin curved line
/// that runs from it down to the replier's name. Tapping it jumps to the
/// original.
struct ChatQuoteLine: View {
    let display: ChatQuote.Display
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            HStack(alignment: .bottom, spacing: 4) {
                ChatSpine()
                    .stroke(ChatStyle.spine, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 26, height: 14)
                text
                    .font(Theme.Typography.Copy.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.bottom, -3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil || display == .unavailable)
        .accessibilityLabel(accessibilityText)
    }

    private var text: Text {
        let bold = Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)
        switch display {
        case .message(let name, let role, let body):
            var head = Text(name).font(bold).foregroundColor(ChatStyle.nameColor(role))
            if role == .supporter { head = head + Text(" ★").font(bold).foregroundColor(Theme.gold) }
            return head + Text(" · " + body).foregroundColor(Theme.subtleText)
        case .mine(let body):
            return Text(L10n.chatQuoteYou).font(bold).foregroundColor(Theme.textPrimary)
                + Text(" · " + body).foregroundColor(Theme.subtleText)
        case .unavailable:
            return Text(L10n.chatQuoteUnavailable).foregroundColor(Theme.subtleText)
        }
    }

    private var accessibilityText: String {
        switch display {
        case .message(let name, _, let body): return "\(L10n.chatReplyTo(name)): \(body)"
        case .mine(let body): return "\(L10n.chatReplyToYou): \(body)"
        case .unavailable: return L10n.chatQuoteUnavailable
        }
    }
}

/// ╭── from the quote, bending down towards the name below.
struct ChatSpine: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 26, sy = rect.height / 14
        var path = Path()
        path.move(to: CGPoint(x: 5 * sx, y: 14 * sy))
        path.addLine(to: CGPoint(x: 5 * sx, y: 9.5 * sy))
        path.addCurve(to: CGPoint(x: 10 * sx, y: 5 * sy),
                      control1: CGPoint(x: 5 * sx, y: 6.5 * sy),
                      control2: CGPoint(x: 7 * sx, y: 5 * sy))
        path.addLine(to: CGPoint(x: 24 * sx, y: 5 * sy))
        return path
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
    var quote: ChatQuote.Display? = nil
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quote {
                ChatQuoteLine(display: quote)
                    .padding(.bottom, -2)
            }
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
