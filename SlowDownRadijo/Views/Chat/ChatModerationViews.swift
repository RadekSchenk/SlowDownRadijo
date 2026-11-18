import SwiftUI
import UIKit

/// What pressing and holding a message offers (Figma L1, L2/Z1, Z4).
enum ChatMenuAction: Equatable {
    case pin, unpin, copy, delete, mute, unmute, block, report, hide
}

/// The actions for `message`, by who is looking (`docs/chat-concept.md` 2d):
/// a listener copies, reports and hides others; a DJ or admin also pins,
/// deletes, mutes and blocks — but never another moderator, nor themselves.
enum ChatMenu {
    static func actions(
        for message: ChatMessage,
        viewer: UUID?,
        isModerator: Bool,
        isPinned: Bool,
        status: ChatService.UserStatus?
    ) -> [ChatMenuAction] {
        if message.isDeleted { return [] }
        let isOwn = message.userID != nil && message.userID == viewer
        let author = message.userID
        var actions: [ChatMenuAction] = []
        if isModerator {
            actions.append(isPinned ? .unpin : .pin)
        }
        actions.append(.copy)
        if isModerator {
            actions.append(.delete)
            let authorIsModerator = message.role == .dj || message.role == .admin
            if author != nil, !isOwn, !authorIsModerator {
                if status?.blocked == true {
                    // Only an admin can lift a block, from the dashboard.
                } else if status?.isMuted == true {
                    actions.append(.unmute)
                    actions.append(.block)
                } else {
                    actions.append(.mute)
                    actions.append(.block)
                }
            }
        } else if viewer != nil, !isOwn {
            actions.append(.report)
            if author != nil { actions.append(.hide) }
        } else if viewer == nil, !isOwn {
            actions.append(.report)
        }
        return actions
    }
}

/// The message menu sheet: the message, when and in which show it was
/// written, then the actions.
struct ChatMessageMenu: View {
    let message: ChatMessage
    let actions: [ChatMenuAction]
    let status: ChatService.UserStatus?
    let onAction: (ChatMenuAction) -> Void

    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ChatAuthorLine(name: ChatStyle.name(message), role: message.role)
                if !message.isDeleted {
                    Text(message.body ?? "")
                        .font(Theme.Typography.Copy.reading)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                }
                Text(ChatTimeline.timeLine(for: message))
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
                if let statusLine {
                    Label(statusLine, systemImage: "speaker.slash")
                        .font(Theme.Typography.Copy.label)
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                if !actions.isEmpty { Divider().overlay(Theme.statsCardRaised) }
            }

            VStack(spacing: 0) {
                ForEach(actions, id: \.self) { action in
                    Button { onAction(action) } label: { row(action) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLine: String? {
        guard let status else { return nil }
        let by = status.mutedBy ?? "—"
        if status.blocked { return L10n.chatBlockedStatus(by) }
        guard let until = status.mutedUntil, until > Date() else { return nil }
        let (day, time) = ProfileFormat.dayAndTime(until)
        return L10n.chatMutedStatus(day, time, by)
    }

    private func row(_ action: ChatMenuAction) -> some View {
        HStack(spacing: 14) {
            Image(systemName: Self.icon(action))
                .font(.system(size: 18))
                .frame(width: 24)
            Text(title(action))
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
            Spacer()
            if action == .unmute, let remaining {
                Text(remaining)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            }
        }
        .foregroundStyle(Self.isDestructive(action) ? Theme.liveRed : Theme.textPrimary)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private var remaining: String? {
        guard let until = status?.mutedUntil else { return nil }
        let minutes = Int(until.timeIntervalSinceNow / 60)
        guard minutes > 0 else { return nil }
        return minutes >= 60 ? L10n.chatRemainingHours(minutes / 60) : L10n.chatRemainingMinutes(minutes)
    }

    private func title(_ action: ChatMenuAction) -> String {
        switch action {
        case .pin: return L10n.chatMenuPin
        case .unpin: return L10n.chatMenuUnpin
        case .copy: return L10n.chatMenuCopy
        case .delete: return L10n.chatMenuDelete
        case .mute: return L10n.chatMenuMute
        case .unmute: return L10n.chatMenuUnmute
        case .block: return L10n.chatMenuBlock
        case .report: return L10n.chatMenuReport
        case .hide: return L10n.chatMenuHide(ChatStyle.name(message))
        }
    }

    static func icon(_ action: ChatMenuAction) -> String {
        switch action {
        case .pin: return "pin"
        case .unpin: return "pin.slash"
        case .copy: return "doc.on.doc"
        case .delete: return "trash"
        case .mute: return "speaker.slash"
        case .unmute: return "speaker.wave.2"
        case .block: return "nosign"
        case .report: return "flag"
        case .hide: return "eye.slash"
        }
    }

    static func isDestructive(_ action: ChatMenuAction) -> Bool {
        [.delete, .mute, .block].contains(action)
    }
}

/// "Ztlumit brancikovac" with 1 h / 24 h / 7 dní (Figma Z2), 24 h preselected.
struct ChatMuteSheet: View {
    let name: String
    let onMute: (_ minutes: Int) -> Void
    let onCancel: () -> Void

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var minutes = 1440

    private var options: [(minutes: Int, title: String)] {
        [(60, L10n.chatMuteHour), (1440, L10n.chatMuteDay), (10080, L10n.chatMuteWeek)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.chatMuteTitle(name))
                .font(Theme.Typography.Heading.hero)
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.chatMuteBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(options, id: \.minutes) { option in
                    Button { minutes = option.minutes } label: {
                        HStack {
                            Text(option.title)
                                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: minutes == option.minutes ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(minutes == option.minutes ? Theme.liveRed : Theme.mutedText)
                        }
                        .frame(height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(minutes == option.minutes ? .isSelected : [])
                    if option.minutes != 10080 { Divider().overlay(Theme.statsCardRaised) }
                }
            }
            PrimaryActionButton(title: actionTitle, isEnabled: true) { onMute(minutes) }
            SecondaryActionButton(title: L10n.cancel, action: onCancel)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private var actionTitle: String {
        switch minutes {
        case 60: return L10n.chatMuteActionHour
        case 10080: return L10n.chatMuteActionWeek
        default: return L10n.chatMuteActionDay
        }
    }
}

/// "Zablokovat brancikovac?" (Figma Z5).
struct ChatBlockSheet: View {
    let name: String
    let onBlock: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.chatBlockTitle(name))
                .font(Theme.Typography.Heading.hero)
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.chatBlockBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryActionButton(title: L10n.chatBlockAction, isEnabled: true, action: onBlock)
            SecondaryActionButton(title: L10n.cancel, action: onCancel)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }
}

/// Opening a DJ invite link (Figma P1–P3): who the invite is for, signing
/// in if needed, then linking the account — or "Pozvánka už neplatí".
struct HostInviteSheet: View {
    let code: String
    let onOpenChat: () -> Void

    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var info: ChatService.InviteInfo?
    @State private var path: [Route] = []
    @State private var isClaiming = false

    enum Phase: Equatable { case loading, ready, done, invalid, otherHost }
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.statsCard)
        .task { await load() }
        .onChange(of: account.state) { _, _ in claimIfReady() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
        case .invalid, .otherHost:
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ProfileHeading(
                    title: L10n.inviteInvalidTitle,
                    bodyText: phase == .otherHost ? AccountError.inviteOtherHost.userMessage : L10n.inviteInvalidBody,
                    titleFont: Theme.Typography.Heading.hero
                )
                SecondaryActionButton(title: L10n.inviteClose) { dismiss() }
            }
        case .ready:
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.inviteKicker.uppercased())
                        .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.liveRed)
                    ProfileHeading(
                        title: info.map { L10n.inviteTitle($0.hostName) } ?? L10n.inviteTitleGeneric,
                        bodyText: L10n.inviteBody,
                        titleFont: Theme.Typography.Heading.hero
                    )
                }
                sample(name: info?.hostName ?? "DJ")
                if account.isSignedIn || isClaiming {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text(L10n.inviteLinking)
                            .font(Theme.Typography.Copy.body)
                            .foregroundStyle(Theme.mutedText)
                    }
                } else {
                    SignInButtons(onEmail: { path.append(.email) })
                }
                Text(validity)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        case .done:
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ProfileHeading(
                    title: L10n.inviteDoneTitle(account.me?.hostName ?? info?.hostName ?? "DJ"),
                    bodyText: L10n.inviteDoneBody,
                    titleFont: Theme.Typography.Heading.hero
                )
                sample(name: account.me?.hostName ?? info?.hostName ?? "DJ")
                Text(L10n.inviteDoneHint)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                PrimaryActionButton(title: L10n.inviteOpenChat, isEnabled: true) {
                    dismiss()
                    onOpenChat()
                }
            }
        }
    }

    private var validity: String {
        guard let expires = info?.expiresAt else { return L10n.inviteOneUse }
        let formatter = DateFormatter()
        formatter.timeZone = ScheduleStore.stationCalendar.timeZone
        formatter.dateFormat = "d. M."
        return L10n.inviteValidUntil(formatter.string(from: expires))
    }

    private func sample(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ChatAuthorLine(name: name, role: .dj)
            Text(L10n.inviteSample)
                .font(Theme.Typography.Copy.reading)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() async {
        do {
            info = try await ChatService.shared.inviteInfo(code)
            phase = info == nil ? .invalid : .ready
            Analytics.shared.track(.djInviteOpened(valid: info != nil))
        } catch {
            // Offline, or the server without `host_invite_info` (021):
            // let the claim decide.
            phase = .ready
            Analytics.shared.track(.djInviteOpened(valid: nil))
        }
        claimIfReady()
    }

    private func claimIfReady() {
        guard phase == .ready, account.isSignedIn, !isClaiming else { return }
        isClaiming = true
        Task {
            defer { isClaiming = false }
            do {
                try await account.claimHostInvite(code)
                Analytics.shared.track(.djInviteClaimed(success: true))
                withAnimation(Motion.cardResize) { phase = .done }
            } catch AccountError.inviteOtherHost {
                Analytics.shared.track(.djInviteClaimed(success: false))
                phase = .otherHost
            } catch AccountError.inviteInvalid {
                Analytics.shared.track(.djInviteClaimed(success: false))
                phase = .invalid
            } catch let error as AccountError {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }
}
