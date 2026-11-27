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
    @State private var pendingKind = "text"
    @State private var menuMessage: ChatMessage?
    @State private var menuStatus: ChatService.UserStatus?
    @State private var muteTarget: ChatMessage?
    @State private var blockTarget: ChatMessage?
    /// Runs once the message menu has closed (the next sheet can't open over it).
    @State private var afterMenu: (() -> Void)?
    @State private var isAtBottom = true
    @State private var bottomSeenID: Int64 = 0
    /// The message being answered (Figma R3): the bar above the field.
    @State private var replyTarget: ChatMessage?
    /// The reply that waits for sign-in together with `pendingText`.
    @State private var pendingReply: ChatMessage?
    /// Where a tapped quote (or a reply on the home page) scrolls to.
    @State private var jumpTarget: Int64?
    /// The original, briefly tinted after the jump (R6).
    @State private var highlightedID: Int64?
    /// Jumped up to an original: "Zpět na nejnovější" until back down.
    @State private var hasJumped = false

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
        // Over the sheet, where the tab view's toasts can't be seen.
        .toastOverlay()
        .onAppear {
            chat.markSeen()
            bottomSeenID = chat.messages.last?.id ?? 0
            if focusComposer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isComposerFocused = true }
            } else if let focus = chat.focusMessageID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { jumpTarget = focus }
            }
            chat.focusMessageID = nil
        }
        .onDisappear { chat.markSeen() }
        .sheet(isPresented: $isShowingJoin, onDismiss: { pendingText = nil; pendingReply = nil }) {
            ChatJoinSheet(onReady: joined)
                .appTextSizeLimit()
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack { ChatRulesView() }
                .appTextSizeLimit()
        }
        .sheet(item: $menuMessage, onDismiss: {
            afterMenu?()
            afterMenu = nil
        }) { message in
            ChatMessageMenu(message: message, actions: menuActions(for: message), status: menuStatus) { action in
                afterMenu = { perform(action, on: message) }
                menuMessage = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.statsCard)
            .appTextSizeLimit()
        }
        .sheet(item: $muteTarget) { message in
            ChatMuteSheet(name: ChatStyle.name(message)) { minutes in
                muteTarget = nil
                mute(message, minutes: minutes)
            } onCancel: {
                muteTarget = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.statsCard)
            .appTextSizeLimit()
        }
        .sheet(item: $blockTarget) { message in
            ChatBlockSheet(name: ChatStyle.name(message)) {
                blockTarget = nil
                block(message)
            } onCancel: {
                blockTarget = nil
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.statsCard)
            .appTextSizeLimit()
        }
    }

    // MARK: - Message menu and moderation (Figma L1, L2, Z1–Z8)

    private var isModerator: Bool { account.isSignedIn && account.me?.isModerator == true }

    private func openMenu(_ message: ChatMessage) {
        guard !message.isDeleted else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isComposerFocused = false
        menuStatus = nil
        menuMessage = message
        if isModerator, let author = message.userID, author != account.me?.userID {
            Task { menuStatus = try? await chat.status(of: author) }
        }
    }

    private func menuActions(for message: ChatMessage) -> [ChatMenuAction] {
        ChatMenu.actions(
            for: message,
            viewer: account.me?.userID,
            isModerator: isModerator,
            isPinned: chat.pinned?.id == message.id,
            status: menuStatus,
            canReply: canReply(message)
        )
    }

    // MARK: - Replies (Figma Chat 1.4, R1–R6)

    private func canReply(_ message: ChatMessage) -> Bool {
        canWrite && !message.isDeleted
    }

    /// R1 (swipe) and R2 (menu): the bar above the field, keyboard up.
    private func startReply(to message: ChatMessage, source: String) {
        guard canReply(message) else { return }
        Analytics.shared.track(.chatReplyStarted(source: source))
        withAnimation(Motion.smoothOut(Motion.fast)) {
            replyTarget = message
            isShowingEmoji = false
        }
        isComposerFocused = true
    }

    private func quote(for message: ChatMessage) -> ChatQuote.Display? {
        message.replyTo?.display(viewer: account.me?.userID, hidden: chat.hiddenUserIDs)
    }

    /// R6: tapping a quote scrolls to the original and tints it for a moment.
    private func jump(to id: Int64, rows: [ChatTimeline.Row], proxy: ScrollViewProxy) {
        guard let rowID = rows.first(where: { row in
            if case .message(let m) = row { return m.id == id }
            return false
        })?.id else { return }
        hasJumped = true
        withAnimation(Motion.smoothOut(Motion.medium)) { proxy.scrollTo(rowID, anchor: .center) }
        withAnimation(Motion.smoothOut(Motion.fast)) { highlightedID = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.smoothOut(Motion.medium)) {
                if highlightedID == id { highlightedID = nil }
            }
        }
    }

    private func toast(_ message: String, icon: String = "checkmark.circle", undoTitle: String? = nil, undo: (() -> Void)? = nil) {
        ToastCenter.shared.show(.init(systemImage: icon, message: message, actionTitle: undoTitle, action: undo))
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
            } catch let error as AccountError {
                toast(error.userMessage, icon: "exclamationmark.circle")
            } catch {}
        }
    }

    private func perform(_ action: ChatMenuAction, on message: ChatMessage) {
        let name = ChatStyle.name(message)
        switch action {
        case .reply:
            startReply(to: message, source: "menu")
        case .copy:
            UIPasteboard.general.string = message.body
        case .pin:
            run {
                try await chat.pin(message)
                Analytics.shared.track(.chatModerated(action: "pin", minutes: nil))
                toast(L10n.chatPinnedToast, icon: "pin")
            }
        case .unpin:
            run {
                try await chat.unpin()
                Analytics.shared.track(.chatModerated(action: "unpin", minutes: nil))
                toast(L10n.chatUnpinnedToast, icon: "pin.slash")
            }
        case .delete:
            run {
                try await chat.delete(message)
                Analytics.shared.track(.chatModerated(action: "delete", minutes: nil))
                toast(L10n.chatDeletedToast, icon: "trash", undoTitle: L10n.chatUndo) {
                    run {
                        try await chat.restore(message)
                        Analytics.shared.track(.chatModerated(action: "restore", minutes: nil))
                    }
                }
            }
        case .mute:
            muteTarget = message
        case .unmute:
            guard let author = message.userID else { return }
            run {
                try await chat.unmute(author)
                Analytics.shared.track(.chatModerated(action: "unmute", minutes: nil))
                toast(L10n.chatUnmutedToast(name), icon: "speaker.wave.2")
            }
        case .block:
            blockTarget = message
        case .report:
            run {
                _ = try? await SupabaseSession.accessToken(creatingAnonymous: true)
                try await chat.report(message)
                Analytics.shared.track(.chatReported)
                toast(L10n.chatReportedToast, icon: "flag")
            }
        case .hide:
            guard let author = message.userID else { return }
            run {
                try await chat.hide(author)
                Analytics.shared.track(.chatUserHidden)
                toast(L10n.chatHiddenToast(name), icon: "eye.slash", undoTitle: L10n.chatUndo) {
                    run { try await chat.unhide(author) }
                }
            }
        }
    }

    private func mute(_ message: ChatMessage, minutes: Int) {
        guard let author = message.userID else { return }
        let name = ChatStyle.name(message)
        run {
            let until = try await chat.mute(author, minutes: minutes, message: message)
                ?? AppClock.now.addingTimeInterval(Double(minutes) * 60)
            Analytics.shared.track(.chatModerated(action: "mute", minutes: minutes))
            let (day, time) = ProfileFormat.dayAndTime(until)
            toast(L10n.chatMutedToast(name, day, time), icon: "speaker.slash", undoTitle: L10n.chatUndo) {
                run { try await chat.unmute(author) }
            }
        }
    }

    private func block(_ message: ChatMessage) {
        guard let author = message.userID else { return }
        let name = ChatStyle.name(message)
        run {
            try await chat.block(author, message: message)
            Analytics.shared.track(.chatModerated(action: "block", minutes: nil))
            toast(L10n.chatBlockedToast(name), icon: "nosign")
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
            .accessibilityIdentifier("chat.close")
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
        // Holding the bar opens the same menu as the message (unpin for moderators).
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.35) { openMenu(message) }
        .accessibilityElement(children: .combine)
        .accessibilityAction { openMenu(message) }
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
                            hasJumped = false
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
                if !isAtBottom, unseenCount > 0 || hasJumped {
                    Button {
                        withAnimation(Motion.smoothOut(Motion.medium)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    } label: {
                        Text(unseenCount > 0 ? "↓ \(L10n.chatNewMessages(unseenCount))" : "\(L10n.chatBackToLatest) ↓")
                            .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(unseenCount > 0 ? Theme.liveRed : Theme.statsCardRaised, in: Capsule())
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
            .onChange(of: jumpTarget) { _, target in
                guard let target else { return }
                jumpTarget = nil
                jump(to: target, rows: rows, proxy: proxy)
            }
        }
    }

    private var unseenCount: Int {
        chat.visibleMessages.filter { $0.id > bottomSeenID }.count
    }

    /// Nobody has written today yet (Figma F).
    private var isQuietToday: Bool {
        let today = ScheduleStore.stationCalendar.startOfDay(for: AppClock.now)
        return !chat.visibleMessages.contains { $0.createdAt >= today } && chat.outgoing.isEmpty
    }

    @ViewBuilder
    private func rowView(_ row: ChatTimeline.Row) -> some View {
        switch row {
        case .divider(_, let text):
            ChatDividerRow(text: text)
        case .message(let message):
            ChatMessageRow(message: message, quote: quote(for: message)) {
                if let id = message.replyTo?.id { jumpTarget = id }
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(highlightedID == message.id ? 0.07 : 0))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
            }
            .swipeToReply(enabled: canReply(message)) { startReply(to: message, source: "swipe") }
            .onLongPressGesture(minimumDuration: 0.35) { openMenu(message) }
            .accessibilityAction(named: L10n.chatMenuReply) { startReply(to: message, source: "accessibility") }
            .accessibilityAction(named: L10n.chatMenuCopy) { UIPasteboard.general.string = message.body }
            .accessibilityAction { openMenu(message) }
        case .emoji(_, let emoji, let count, let names):
            ChatEmojiGroupRow(emoji: emoji, count: count, names: names)
        case .outgoing(let message):
            ChatOutgoingRow(
                message: message,
                name: account.me?.chatName ?? "",
                role: account.me.map { ChatMessage.Role(rawValue: $0.role.rawValue) ?? .listener } ?? .listener,
                quote: message.replyTo?.display(viewer: account.me?.userID, hidden: chat.hiddenUserIDs)
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
                        Button { submit(text, clearsDraft: false, kind: ChatStyle.quickEmoji.contains(text) ? "emoji" : "starter") } label: {
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
        guard let until = account.me?.mutedUntil, until > AppClock.now else { return nil }
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
                if let replyTarget {
                    replyBar(replyTarget)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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

    /// R3: "Odpovídáš: karolina.pivnivila ★" and the start of the message,
    /// a stripe in the author's colour, ✕ to cancel (the text stays).
    private func replyBar(_ message: ChatMessage) -> some View {
        let name = ChatStyle.name(message) + (message.role == .supporter ? " ★" : "")
        let bold = Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)
        return HStack(spacing: 10) {
            Rectangle()
                .fill(ChatStyle.nameColor(message.role))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                (Text(L10n.chatReplyingTo("")).foregroundColor(Theme.subtleText)
                 + Text(name).font(bold).foregroundColor(ChatStyle.nameColor(message.role)))
                    .font(Theme.Typography.Copy.label)
                    .lineLimit(1)
                Text((message.body ?? "").split(whereSeparator: \.isNewline).joined(separator: " "))
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(1)
            }
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(Motion.smoothOut(Motion.fast)) { replyTarget = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.mutedText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.chatReplyCancel)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.statsCardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
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
                Button { submit(emoji, clearsDraft: false, kind: "emoji") } label: {
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
        if let name = account.me?.chatName {
            (Text(L10n.chatWritingAs + " ").foregroundColor(Theme.subtleText)
             + Text(name).font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)).foregroundColor(Theme.mutedText))
                .font(Theme.Typography.Copy.label)
                .lineLimit(1)
        } else {
            Text(L10n.chatFirstMessageHint)
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

    private func submit(_ raw: String, clearsDraft: Bool, kind: String = "text") {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard account.canWriteInChat else {
            // The first message: a nickname first (no account needed), then
            // this goes out by itself (Figma Chat J1–J3).
            Analytics.shared.track(.chatNicknamePromptShown)
            pendingText = text
            pendingKind = kind
            pendingReply = replyTarget
            isComposerFocused = false
            isShowingJoin = true
            return
        }
        let reply = replyTarget
        withAnimation(Motion.smoothOut(Motion.fast)) {
            if clearsDraft { draft = "" }
            replyTarget = nil
        }
        send(text, announce: false, kind: kind, replyTo: reply)
    }

    private func send(_ text: String, announce: Bool, kind: String, replyTo: ChatMessage? = nil) {
        let first = (account.me?.chatMessagesCount ?? 0) == 0 && !chat.messages.contains { $0.userID == account.me?.userID }
        Task {
            do {
                try await chat.send(text, show: scheduleStore.currentShow() ?? nowPlaying.currentShow, replyTo: replyTo)
                Analytics.shared.track(.chatMessageSent(kind: kind, success: true, first: first, account: account.analyticsAccount, isReply: replyTo != nil))
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                if announce, let name = account.me?.chatName {
                    ToastCenter.shared.show(.init(systemImage: "checkmark.circle", message: L10n.chatSentAs(name)))
                }
            } catch AccountError.nicknameRequired {
                pendingText = text
                pendingKind = kind
                pendingReply = replyTo
                isShowingJoin = true
            } catch let error as AccountError {
                Analytics.shared.track(.chatMessageSent(kind: kind, success: false, first: first, account: account.analyticsAccount, isReply: replyTo != nil))
                if case .offline = error { return } // shown on the message itself
                if case .linksNeedAccount = error, draft.isEmpty {
                    // Back in the field, to take the link out.
                    draft = text
                    replyTarget = replyTo
                }
                if case .replyUnavailable = error, draft.isEmpty, kind == "text" {
                    // The original is gone: the text comes back, as a plain message.
                    draft = text
                }
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }

    private func joined() {
        isShowingJoin = false
        guard let text = pendingText else { return }
        pendingText = nil
        let reply = pendingReply
        pendingReply = nil
        if replyTarget?.id == reply?.id { replyTarget = nil }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text {
            withAnimation(Motion.smoothOut(Motion.fast)) { draft = "" }
        }
        send(text, announce: true, kind: pendingKind, replyTo: reply)
    }
}

// MARK: - Swipe to reply (Figma R1)

private struct SwipeToReply: ViewModifier {
    let enabled: Bool
    let onReply: () -> Void

    @State private var offset: CGFloat = 0
    @State private var armed = false

    static let threshold: CGFloat = 56

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Theme.statsCardRaised, in: Circle())
                    .scaleEffect(armed ? 1 : 0.8)
                    .opacity(Double(min(1, offset / Self.threshold)))
                    .accessibilityHidden(true)
            }
            .modifier(ReplyDrag(enabled: enabled, onChange: track, onEnd: finish, drag: drag))
    }

    /// On iOS 18 a SwiftUI DragGesture on a row inside the ScrollView takes
    /// the vertical pans from it, so the list barely scrolls. A UIKit pan that
    /// only begins for a rightward, mostly horizontal swipe leaves every other
    /// touch to the scroll view.
    private struct ReplyDrag<G: Gesture>: ViewModifier {
        let enabled: Bool
        let onChange: (CGFloat) -> Void
        let onEnd: () -> Void
        let drag: G

        func body(content: Content) -> some View {
            if !enabled {
                content
            } else if #available(iOS 18.0, *) {
                content.gesture(HorizontalSwipe(onChange: onChange, onEnd: onEnd))
            } else {
                content.simultaneousGesture(drag)
            }
        }
    }

    private func track(_ dx: CGFloat) {
        let dx = max(0, dx)
        // Follows the finger up to the threshold, then slower.
        offset = dx <= Self.threshold ? dx : Self.threshold + (dx - Self.threshold) * 0.25
        let nowArmed = offset >= Self.threshold
        if nowArmed != armed {
            armed = nowArmed
            if nowArmed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func finish() {
        if armed { onReply() }
        armed = false
        withAnimation(Motion.smoothOut(Motion.medium)) { offset = 0 }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                guard dx > 0, dx > abs(dy) * 1.5 || offset > 0 else { return }
                track(dx)
            }
            .onEnded { _ in finish() }
    }
}

/// A pan that begins only when the finger moves right more than it moves up
/// or down; vertical drags fail it at once and stay with the scroll view.
@available(iOS 18.0, *)
private struct HorizontalSwipe: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(recognizer.translation(in: recognizer.view).x)
        case .ended, .cancelled, .failed: onEnd()
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return v.x > 0 && v.x > abs(v.y) * 1.5
        }
    }
}

extension View {
    func swipeToReply(enabled: Bool, onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReply(enabled: enabled, onReply: onReply))
    }
}

/// Before the first message (Figma Chat J1–J3): "Tvoje přezdívka", no
/// account needed. "Už máš účet? Přihlas se" turns it into signing in with an
/// existing account (H), which brings the nickname and stats back.
/// Calls `onReady` once the listener has a name to write under.
struct ChatJoinSheet: View {
    let onReady: () -> Void

    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []
    @State private var mode: Mode = .nickname
    @State private var nickname = ""
    @State private var status: NicknameField.Status = .empty
    @State private var isSaving = false
    @State private var isShowingRules = false
    @State private var didFinish = false

    enum Route: Hashable { case email }
    enum Mode { case nickname, signIn }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                Group {
                    if account.canWriteInChat {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if mode == .signIn && !account.isSignedIn {
                        signIn.transition(.reveal)
                    } else {
                        nicknameStep.transition(.reveal)
                    }
                }
                .animation(Motion.smoothOut(Motion.medium), value: mode)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.statsCard.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { _ in
                EmailSignInView(onSignedIn: { path.removeAll() })
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.statsCard)
        .onChange(of: account.state, initial: true) { _, _ in
            if account.canWriteInChat, !didFinish {
                didFinish = true
                onReady()
            }
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack { ChatRulesView() }
        }
    }

    // J1–J3

    private var nicknameStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileHeading(title: L10n.chatNicknameTitle, bodyText: L10n.chatNicknameBody, titleFont: Theme.Typography.Heading.hero)
            VStack(alignment: .leading, spacing: 8) {
                NicknameField(text: $nickname, status: $status)
                Text(L10n.chatNicknameRules)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryActionButton(title: L10n.chatNicknameSend, isEnabled: status.canSave && !isSaving, action: save)
                .animation(Motion.smoothOut(Motion.fast), value: status.canSave)
            if !account.isSignedIn {
                Button {
                    Analytics.shared.track(.registrationPromptShown(reason: "chat_existing_account"))
                    AccountService.shared.registrationSource = "chat_existing_account"
                    mode = .signIn
                } label: {
                    (Text(L10n.chatHaveAccount + " ").foregroundColor(Theme.mutedText)
                     + Text(L10n.chatSignInLink).foregroundColor(Theme.textPrimary).underline())
                        .font(Theme.Typography.Copy.body)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await account.setNickname(nickname.trimmingCharacters(in: .whitespaces))
                Analytics.shared.track(.chatNicknameSet(when: "first_message"))
            } catch let error as AccountError {
                applyError(error, to: &status)
            } catch {}
        }
    }

    // H

    private var signIn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileHeading(title: L10n.chatSignInTitle, bodyText: L10n.chatSignInBody, titleFont: Theme.Typography.Heading.hero)
            SignInButtons(onEmail: { path.append(.email) })
            Button(L10n.chatBackToNickname) { mode = .nickname }
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
