import SwiftUI

/// The chat on the home page (Figma "A1 · Homepage — chat"): no frame, the
/// "Chat" heading like the other sections with a chevron, the last four
/// messages one line each — the newest at the bottom in white, older ones
/// fading out (40 / 60 / 80 / 100 %) — and a "Napiš zprávu…" field.
///
/// Tapping the field opens the chat with the keyboard up; tapping anywhere
/// else opens it without. Nobody needs to sign in to start typing — that
/// comes when sending.
///
/// Ticker: new messages arrive by movement, not a number. On opening the
/// app the section shows what the listener already saw, then 600 ms later
/// plays the new ones one after another (1.2 s apart, at most four; more
/// than four arrive as one change). With Reduce Motion they just appear.
struct ChatHomeSection: View {
    let onOpen: (_ withKeyboard: Bool) -> Void

    @ObservedObject private var chat = ChatService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [ChatTimeline.HomeLine] = []
    @State private var started = false
    @State private var isPlaying = false

    static let lineCount = 4
    private static let lineHeight: CGFloat = 20
    private static let lineSpacing: CGFloat = 6
    private static let opacities: [Double] = [1, 0.8, 0.6, 0.4]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button { onOpen(false) } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Text(L10n.chatTitle)
                            .font(Theme.Typography.Heading.section)
                            .foregroundStyle(Theme.textPrimary)
                            .manropeLineHeight(26, fontSize: 19)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.mutedText)
                    }
                    lines
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.chatOpen)

            Button { onOpen(true) } label: {
                HStack {
                    Text(L10n.chatPlaceholder)
                        .font(Theme.Typography.Copy.reading)
                        .foregroundStyle(Theme.subtleText)
                    Spacer()
                    Image(systemName: "face.smiling")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.mutedText)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .onAppear(perform: sync)
        .onChange(of: chat.messages) { _, _ in sync() }
        .onChange(of: chat.hiddenUserIDs) { _, _ in sync() }
        .onChange(of: chat.lastSeenID) { _, _ in sync() }
    }

    // MARK: - Lines

    @ViewBuilder
    private var lines: some View {
        if isQuiet {
            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                if let pinned = chat.pinned, let body = pinned.body {
                    (Text(Image(systemName: "pin.fill")).foregroundColor(Theme.liveRed)
                     + Text(" ") + nameText(pinned) + Text("  ") + Text(body).foregroundColor(Theme.textPrimary))
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .lineLimit(1)
                }
                Text(L10n.chatHomeQuiet)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, homeLine in
                    let fromBottom = shown.count - 1 - index
                    line(homeLine, isNewest: fromBottom == 0)
                        .opacity(Self.opacities[min(fromBottom, Self.opacities.count - 1)])
                        .transition(.asymmetric(
                            insertion: .modifier(
                                active: TickerInsert(offset: 8, blur: 2, opacity: 0),
                                identity: TickerInsert(offset: 0, blur: 0, opacity: 1)
                            ),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .bottom)
            .clipped()
        }
    }

    private var height: CGFloat {
        let count = CGFloat(max(1, min(Self.lineCount, shown.count)))
        return count * Self.lineHeight + (count - 1) * Self.lineSpacing
    }

    private func line(_ homeLine: ChatTimeline.HomeLine, isNewest: Bool) -> some View {
        let message = homeLine.message
        let count = homeLine.count > 1 ? " ×\(homeLine.count)" : ""
        return (nameText(message) + Text("  ") + Text((message.body ?? "") + count).foregroundColor(isNewest ? Theme.textPrimary : Theme.mutedText))
            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
            .lineLimit(1)
            .frame(height: Self.lineHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nameText(_ message: ChatMessage) -> Text {
        var name = Text(ChatStyle.name(message))
            .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
            .foregroundColor(ChatStyle.nameColor(message.role))
        if message.role == .supporter {
            name = name + Text(" ★").foregroundColor(Theme.gold)
        }
        return name
    }

    /// Nothing written in the last 24 hours (Figma "A2 · Homepage — ticho").
    private var isQuiet: Bool {
        guard chat.isLoaded else { return false }
        guard let newest = candidates.last else { return true }
        return newest.message.createdAt < Date().addingTimeInterval(-24 * 3600)
    }

    private var candidates: [ChatTimeline.HomeLine] {
        ChatTimeline.homeLines(chat.visibleMessages.filter { !$0.isDeleted })
    }

    // MARK: - Ticker

    private func sync() {
        let all = candidates
        if !started {
            guard chat.isLoaded else { return }
            started = true
            shown = Array(all.filter { $0.id <= chat.lastSeenID }.suffix(Self.lineCount))
        }
        // Renamed, deleted or hidden since: update what's on screen.
        shown = shown.compactMap { old in all.first { $0.id == old.id } }
        // Read in the open chat meanwhile (the listener's own messages too):
        // shown as they are, the ticker only plays what nobody has seen.
        let seen = all.filter { $0.id <= chat.lastSeenID }
        if let newestSeen = seen.last, newestSeen.id > (shown.last?.id ?? 0) {
            shown = Array(seen.suffix(Self.lineCount))
        }
        play()
    }

    private func play() {
        guard !isPlaying else { return }
        isPlaying = true
        Task { @MainActor in
            defer { isPlaying = false }
            var first = true
            while true {
                let all = candidates
                let after = shown.last?.id ?? chat.lastSeenID
                let pending = all.filter { $0.id > after }
                guard !pending.isEmpty else { break }

                try? await Task.sleep(for: .milliseconds(first ? 600 : 1200))
                first = false

                if pending.count > Self.lineCount || reduceMotion {
                    // One change for a big batch.
                    let target = Array(all.suffix(Self.lineCount))
                    if reduceMotion {
                        shown = target
                    } else {
                        withAnimation(Motion.smoothOut(Motion.medium)) { shown = target }
                    }
                } else {
                    withAnimation(Motion.smoothOut(Motion.medium)) {
                        shown.append(pending[0])
                        if shown.count > Self.lineCount { shown.removeFirst(shown.count - Self.lineCount) }
                    }
                }
                if let newest = shown.last { chat.markSeen(upTo: newest.id) }
            }
        }
    }
}

/// The ticker's entrance: from 8 pt lower through a 2 pt blur (P22 Reveal).
private struct TickerInsert: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .blur(radius: blur)
            .opacity(opacity)
    }
}
