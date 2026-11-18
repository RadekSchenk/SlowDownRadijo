import SwiftUI
import UIKit

/// The chat (Figma "Chat sheet", B–G, K, L3): a sheet over the home page, so
/// the show and the player stay in sight above it.
///
/// Header with the show on air, the pinned message, the stream with its
/// dividers, then the composer: quick emoji, the field and send. Signed out,
/// the listener types as anyone else; sending asks them to sign in (H) and
/// sends the draft right after (draft-first). Muted or blocked, the composer
/// gives way to a banner (L3).
struct ChatSheetView: View {
    @ObservedObject var nowPlaying: NowPlayingViewModel
    @ObservedObject var scheduleStore: ScheduleStore
    var focusComposer = false

    @ObservedObject private var chat = ChatService.shared
    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposerFocused: Bool
    @State private var draft = ""
    @State private var isShowingEmoji = false
    @State private var isShowingJoin = false
    @State private var isShowingRules = false
    /// Waiting for sign-in: the text to send once the listener has a name.
    @State private var pendingText: String?
    @State private var isAtBottom = true
    @State private var bottomSeenID: Int64 = 0

    private static let bottomID = "chat-bottom"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.statsCardRaised)
            if let pinned = chat.pinned {
                pinnedBar(pinned)
            }
            stream
            Divider().overlay(Theme.statsCardRaised)
            composer
        }
        .background(Theme.statsCard.ignoresSafeArea())
        .onAppear {
            chat.markSeen()
            bottomSeenID = chat.messages.last?.id ?? 0
            if focusComposer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isComposerFocused = true }
            }
        }
        .onDisappear { chat.markSeen() }
        .sheet(isPresented: $isShowingJoin, onDismiss: { pendingText = nil }) {
            ChatJoinSheet(onReady: joined)
                .appTextSizeLimit()
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack { ChatRulesView() }
                .appTextSizeLimit()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.chatTitle)
                    .font(Theme.Typography.Heading.hero)
                    .foregroundStyle(Theme.textPrimary)
                if let show = nowPlaying.currentShow {
                    Text([show.displayTitle, show.hostName].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.Typography.Copy.label)
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Theme.statsCardRaised, in: Circle())
            }
            .accessibilityLabel(L10n.chatClose)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private func pinnedBar(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.liveRed)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.chatPinned) · \(ChatStyle.name(message))")
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.liveRed)
                Text(message.body ?? "")
                    .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.statsCard)
        .overlay(alignment: .bottom) { Divider().overlay(Theme.statsCardRaised) }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stream

    private var rows: [ChatTimeline.Row] {
        ChatTimeline.rows(
            messages: chat.messages,
            outgoing: chat.outgoing,
            outgoingShow: chat.outgoingShow,
            hidden: chat.hiddenUserIDs,
            showLabel: showLabel
        )
    }

    private func showLabel(_ showID: String?, _ title: String?, _ date: Date) -> ChatTimeline.ShowLabel? {
        guard let showID else { return nil }
        let scheduled = scheduleStore.show(at: date).flatMap { $0.id == showID ? $0 : nil }
        let show = scheduled ?? scheduleStore.knownShow(id: showID)
        guard let name = title ?? show?.displayTitle else { return nil }
        return .init(start: show?.start, title: name)
    }

    private var stream: some View {
        let rows = rows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !chat.isLoaded {
                        if chat.loadFailed {
                            Text(L10n.chatLoadFailed)
                                .font(Theme.Typography.Copy.body)
                                .foregroundStyle(Theme.mutedText)
                        } else {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(rows) { row in
                        rowView(row)
                    }
                    if chat.isLoaded, isQuietToday {
                        quietState
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                        .onAppear {
                            isAtBottom = true
                            bottomSeenID = chat.messages.last?.id ?? 0
                            chat.markSeen()
                        }
                        .onDisappear { isAtBottom = false }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) {
                if !isAtBottom, unseenCount > 0 {
                    Button {
                        withAnimation(Motion.smoothOut(Motion.medium)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    } label: {
                        Text("↓ \(L10n.chatNewMessages(unseenCount))")
                            .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Theme.liveRed, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                    .transition(.reveal)
                }
            }
            .onChange(of: rows.last?.id) { _, _ in
                if isAtBottom || !chat.outgoing.isEmpty {
                    withAnimation(Motion.smoothOut(Motion.medium)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
        }
    }

    private var unseenCount: Int {
        chat.visibleMessages.filter { $0.id > bottomSeenID }.count
    }

    /// Nobody has written today yet (Figma F).
    private var isQuietToday: Bool {
        let today = ScheduleStore.stationCalendar.startOfDay(for: Date())
        return !chat.visibleMessages.contains { $0.createdAt >= today } && chat.outgoing.isEmpty
    }

    @ViewBuilder
    private func rowView(_ row: ChatTimeline.Row) -> some View {
        switch row {
        case .divider(_, let text):
            ChatDividerRow(text: text)
        case .message(let message):
            ChatMessageRow(message: message)
                .contextMenu {
                    Section(ChatTimeline.timeLine(for: message)) {
                        if let body = message.body, !message.isDeleted {
                            Button {
                                UIPasteboard.general.string = body
                            } label: {
                                Label(L10n.chatCopy, systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
        case .emoji(_, let emoji, let count, let names):
            ChatEmojiGroupRow(emoji: emoji, count: count, names: names)
        case .outgoing(let message):
            ChatOutgoingRow(
                message: message,
                name: account.me?.chatName ?? "",
                role: account.me.map { ChatMessage.Role(rawValue: $0.role.rawValue) ?? .listener } ?? .listener
            ) {
                Task { try? await chat.retry(message.id) }
            }
        }
    }

    private var quietState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.chatQuietTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.chatQuietBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            if canWrite {
                HStack(spacing: 8) {
                    ForEach([L10n.chatStarterHello, L10n.chatStarterWhatPlayed, "🔥"], id: \.self) { text in
                        Button { submit(text, clearsDraft: false) } label: {
                            Text(text)
                                .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(Theme.statsCardRaised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Composer

    private var mutedUntil: Date? {
        guard let until = account.me?.mutedUntil, until > Date() else { return nil }
        return until
    }

    private var isBlocked: Bool { account.me?.blocked == true }

    private var canWrite: Bool { mutedUntil == nil && !isBlocked }

    @ViewBuilder
    private var composer: some View {
        if canWrite {
            VStack(alignment: .leading, spacing: 10) {
                if !isShowingEmoji {
                    quickEmoji
                }
                HStack(spacing: 10) {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField(L10n.chatPlaceholder, text: $draft, axis: .vertical)
                            .font(Theme.Typography.Copy.reading)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1...4)
                            .focused($isComposerFocused)
                            .padding(.vertical, 11)
                            .onChange(of: isComposerFocused) { _, focused in
                                if focused { isShowingEmoji = false }
                            }
                            .onChange(of: draft) { _, new in
                                if new.count > 500 { draft = String(new.prefix(500)) }
                            }
                        Button {
                            isComposerFocused = false
                            withAnimation(Motion.cardResize) { isShowingEmoji.toggle() }
                        } label: {
                            Image(systemName: isShowingEmoji ? "keyboard" : "face.smiling")
                                .font(.system(size: 19))
                                .foregroundStyle(Theme.mutedText)
                                .frame(width: 36, height: 44)
                        }
                        .accessibilityLabel(L10n.chatEmoji)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 4)
                    .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    sendButton
                }
                footer
                if isShowingEmoji {
                    emojiPicker
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        } else {
            mutedBanner
        }
    }

    private var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var sendButton: some View {
        Button { submit(draft, clearsDraft: true) } label: {
            Image(systemName: "paperplane")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(hasDraft ? Theme.textPrimary : Theme.mutedText)
                .frame(width: 44, height: 44)
                .background(hasDraft ? Theme.liveRed : Theme.statsCardRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!hasDraft)
        .accessibilityLabel(L10n.chatSend)
        .animation(Motion.smoothOut(Motion.fast), value: hasDraft)
    }

    private var quickEmoji: some View {
        HStack(spacing: 8) {
            ForEach(ChatStyle.quickEmoji, id: \.self) { emoji in
                Button { submit(emoji, clearsDraft: false) } label: {
                    Text(emoji)
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.chatEmoji)
                .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.mutedText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                ForEach(ChatStyle.pickerEmoji, id: \.self) { emoji in
                    Button { draft += emoji } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var footer: some View {
        if let name = account.me?.chatName, account.isSignedIn {
            (Text(L10n.chatWritingAs + " ").foregroundColor(Theme.subtleText)
             + Text(name).font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)).foregroundColor(Theme.mutedText))
                .font(Theme.Typography.Copy.label)
                .lineLimit(1)
        } else {
            Text(L10n.chatSignInToSend)
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(Theme.subtleText)
        }
    }

    private var mutedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isBlocked {
                Text(L10n.blockedBanner)
                    .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
            } else if let mutedUntil {
                let (day, time) = ProfileFormat.dayAndTime(mutedUntil)
                Text(L10n.mutedBanner(day: day, time: time))
                    .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
            }
            HStack(spacing: 4) {
                Text(L10n.mutedBannerBody)
                    .foregroundStyle(Theme.mutedText)
                Button(L10n.chatShowRules) { isShowingRules = true }
                    .foregroundStyle(Theme.textPrimary)
                    .underline()
            }
            .font(Theme.Typography.Copy.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Sending

    private var hasName: Bool { account.isSignedIn && account.me?.chatName != nil }

    private func submit(_ raw: String, clearsDraft: Bool) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard hasName else {
            // Draft-first: sign in, then this goes out by itself.
            pendingText = text
            isComposerFocused = false
            isShowingJoin = true
            return
        }
        if clearsDraft { draft = "" }
        send(text, announce: false)
    }

    private func send(_ text: String, announce: Bool) {
        Task {
            do {
                try await chat.send(text, show: scheduleStore.currentShow() ?? nowPlaying.currentShow)
                if announce, let name = account.me?.chatName {
                    ToastCenter.shared.show(.init(systemImage: "checkmark.circle", message: L10n.chatSentAs(name)))
                }
            } catch AccountError.nicknameRequired {
                pendingText = text
                isShowingJoin = true
            } catch let error as AccountError {
                if case .offline = error { return } // shown on the message itself
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }

    private func joined() {
        isShowingJoin = false
        guard let text = pendingText else { return }
        pendingText = nil
        if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
        send(text, announce: true)
    }
}

/// "Připoj se do chatu" (Figma H), then the nickname (J) for a new account.
/// Calls `onReady` once the listener can write.
struct ChatJoinSheet: View {
    let onReady: () -> Void

    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []
    @State private var detent: PresentationDetent = .medium
    @State private var isShowingRules = false
    @State private var didFinish = false

    enum Route: Hashable { case email }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
            }
            .background(Theme.statsCard.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { _ in
                EmailSignInView(onSignedIn: { path.removeAll() })
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.statsCard)
        .onChange(of: path) { _, new in detent = new.isEmpty && !needsNickname ? .medium : .large }
        .onChange(of: account.state, initial: true) { _, _ in
            if needsNickname { detent = .large }
            if canWrite, !didFinish {
                didFinish = true
                onReady()
            }
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack { ChatRulesView() }
        }
    }

    private var needsNickname: Bool {
        guard account.isSignedIn, let me = account.me else { return false }
        return me.chatName == nil
    }

    private var canWrite: Bool {
        account.isSignedIn && account.me?.chatName != nil
    }

    @ViewBuilder
    private var content: some View {
        if needsNickname {
            NicknameSetupView()
        } else if account.isSignedIn {
            ProgressView().tint(.white).frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ProfileHeading(title: L10n.chatJoinTitle, bodyText: L10n.chatJoinBody, titleFont: Theme.Typography.Heading.hero)
                SignInButtons(onEmail: { path.append(.email) })
                Button(L10n.chatNotNow) { dismiss() }
                    .font(Theme.Typography.Copy.link)
                    .foregroundStyle(Theme.mutedText)
                    .frame(maxWidth: .infinity)
                Button { isShowingRules = true } label: {
                    Text(L10n.chatJoinLegal)
                        .font(Theme.Typography.Copy.label)
                        .foregroundStyle(Theme.subtleText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
