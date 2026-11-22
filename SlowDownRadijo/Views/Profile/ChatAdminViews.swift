import SwiftUI
import UIKit

/// Routes inside Profil for the superadmin's "Správa chatu".
enum AdminRoute: Hashable {
    case moderators
    case invite(preselected: String?)
    case inviteReady(ChatAdmin.Invite, name: String)
    case moderator(String)
    case admins
    case addAdmin
}

/// One screen of the "Správa chatu" pages: back, title, content.
struct AdminPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: title, onBack: { dismiss() })
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private func adminBody(_ text: String) -> some View {
    Text(text)
        .font(Theme.Typography.Copy.body)
        .foregroundStyle(Theme.mutedText)
        .fixedSize(horizontal: false, vertical: true)
}

private func adminRow(_ title: String, _ subtitle: String?, subtitleColor: Color = Theme.subtleText, chevron: Bool = true, badge: Bool = false) -> some View {
    HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.Typography.Heading.item)
                    .foregroundStyle(Theme.textPrimary)
                if badge { ChatHostTag() }
            }
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(subtitleColor)
            }
        }
        Spacer()
        if chevron {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mutedText)
        }
    }
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline(0.08)).frame(height: 1) }
}

private func shortDate(_ date: Date?) -> String {
    guard let date else { return "" }
    let formatter = DateFormatter()
    formatter.timeZone = ScheduleStore.stationCalendar.timeZone
    formatter.dateFormat = "d. M. yyyy"
    return formatter.string(from: date)
}

@MainActor
private func toastError(_ error: Error) {
    let message = (error as? AccountError)?.userMessage ?? L10n.errorGeneric
    ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: message))
}

// MARK: - A1 Moderátoři

struct AdminModeratorsView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var admin = ChatAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        AdminPage(title: L10n.adminModerators) {
            adminBody(L10n.adminModeratorsBody)
            VStack(spacing: 0) {
                ForEach(rows, id: \.id) { row in
                    NavigationLink(value: ProfileView.Route.admin(.moderator(row.id))) {
                        adminRow(row.name, row.status, subtitleColor: row.statusColor, badge: row.linked)
                    }
                    .buttonStyle(.plain)
                    .transition(.reveal)
                }
            }
            .animation(Motion.smoothOut(Motion.medium), value: rows.map(\.id))
            NavigationLink(value: ProfileView.Route.admin(.invite(preselected: nil))) {
                Text(L10n.adminInviteModerator)
                    .font(Theme.Typography.Copy.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.liveRed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .task { do { try await admin.reload() } catch { toastError(error) } }
    }

    struct Row {
        let id: String
        let name: String
        let status: String
        let statusColor: Color
        let linked: Bool
    }

    private var rows: [Row] {
        let programme = ChatAdmin.programmeHosts(scheduleStore)
        let hosts = admin.overview?.hosts ?? []
        var ids = programme.map(\.id)
        for host in hosts where !ids.contains(host.hostID) { ids.append(host.hostID) }
        return ids.map { id in
            let p = programme.first { $0.id == id }
            let h = hosts.first { $0.hostID == id }
            let name = h?.displayName ?? p?.name ?? id
            let shows = (p?.shows ?? []).joined(separator: ", ")
            if h?.linked == true {
                return Row(id: id, name: name, status: shows.isEmpty ? L10n.adminLinked : "\(L10n.adminLinked) · \(shows)", statusColor: Theme.subtleText, linked: true)
            }
            if let expires = h?.inviteExpiresAt {
                return Row(id: id, name: name, status: L10n.adminInvitePending(shortDate(expires)), statusColor: Theme.gold, linked: false)
            }
            return Row(id: id, name: name, status: L10n.adminNoAccount, statusColor: Theme.subtleText, linked: false)
        }
        .sorted { ($0.linked ? 0 : 1, $0.name) < ($1.linked ? 0 : 1, $1.name) }
    }
}

// MARK: - A2 Pozvat moderátora

struct AdminInviteView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    let preselected: String?
    @Binding var path: [ProfileView.Route]

    @ObservedObject private var admin = ChatAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selected: String?
    @State private var guestName = ""
    @State private var isWorking = false

    private static let guestID = "_guest"

    var body: some View {
        let hosts = ChatAdmin.programmeHosts(scheduleStore)
        let linked = Set((admin.overview?.hosts ?? []).filter(\.linked).map(\.hostID))
        AdminPage(title: L10n.adminInviteModerator) {
            adminBody(L10n.adminInviteBody)
            VStack(spacing: 0) {
                ForEach(hosts) { host in
                    radioRow(id: host.id, title: host.name, subtitle: linked.contains(host.id) ? L10n.adminAlreadyLinked : host.shows.joined(separator: ", "), disabled: linked.contains(host.id))
                }
                radioRow(id: Self.guestID, title: L10n.adminGuestHost, subtitle: L10n.adminGuestHostBody, disabled: false)
                if selected == Self.guestID {
                    TextField(L10n.adminGuestNamePlaceholder, text: $guestName)
                        .font(Theme.Typography.Copy.reading)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.top, 12)
                        .transition(.reveal)
                }
            }
            .animation(Motion.smoothOut(Motion.medium), value: selected)
            PrimaryActionButton(title: L10n.adminCreateInvite, isEnabled: canCreate && !isWorking) { create(hosts) }
        }
        .task {
            selected = preselected
            if admin.overview == nil { try? await admin.reload() }
        }
    }

    private var canCreate: Bool {
        guard let selected else { return false }
        if selected == Self.guestID { return guestName.trimmingCharacters(in: .whitespaces).count >= 2 }
        return true
    }

    private func radioRow(id: String, title: String, subtitle: String, disabled: Bool) -> some View {
        Button { selected = id } label: {
            HStack(spacing: 12) {
                Image(systemName: selected == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected == id ? Theme.liveRed : Theme.mutedText)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Typography.Heading.item).foregroundStyle(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(Theme.Typography.Copy.label).foregroundStyle(Theme.subtleText).lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline(0.08)).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityAddTraits(selected == id ? .isSelected : [])
    }

    private func create(_ hosts: [ChatAdmin.ProgrammeHost]) {
        guard let selected else { return }
        let name: String
        let id: String
        if selected == Self.guestID {
            name = guestName.trimmingCharacters(in: .whitespaces)
            id = ChatAdmin.hostID(for: name)
        } else {
            id = selected
            name = hosts.first { $0.id == selected }?.name ?? selected
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let invite = try await admin.createInvite(hostID: id, name: name)
                Analytics.shared.track(.adminInviteCreated(fromProgramme: selected != Self.guestID))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                path.append(.admin(.inviteReady(invite, name: name)))
            } catch {
                toastError(error)
            }
        }
    }
}

// MARK: - A3 Pozvánka je připravená

struct AdminInviteReadyView: View {
    let invite: ChatAdmin.Invite
    let name: String

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var copied = false
    @State private var appeared = false

    var body: some View {
        AdminPage(title: L10n.adminInviteReady) {
            adminBody(L10n.adminInviteReadyBody(name))
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                    .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                Text(L10n.adminInviteValidity(shortDate(invite.expiresAt)))
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(appeared ? 1 : 0.97)
            .opacity(appeared ? 1 : 0)
            ShareLink(item: invite.url, message: Text(L10n.adminInviteShareMessage(name))) {
                Text(L10n.adminShareLink)
                    .font(Theme.Typography.Copy.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.liveRed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .simultaneousGesture(TapGesture().onEnded { Analytics.shared.track(.adminInviteShared(via: "share")) })
            Button {
                UIPasteboard.general.url = invite.url
                Analytics.shared.track(.adminInviteShared(via: "copy"))
                withAnimation(Motion.smoothOut(Motion.fast)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(Motion.smoothOut(Motion.fast)) { copied = false }
                }
            } label: {
                Label(copied ? L10n.adminCopied : L10n.adminCopyLink, systemImage: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .font(Theme.Typography.Copy.button)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .onAppear { withAnimation(Motion.smoothOut(Motion.medium).delay(0.1)) { appeared = true } }
    }
}

// MARK: - A4 Detail moderátora

struct AdminModeratorDetailView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    let hostID: String
    @Binding var path: [ProfileView.Route]

    @ObservedObject private var admin = ChatAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isConfirmingUnlink = false
    @State private var isWorking = false

    var body: some View {
        let programme = ChatAdmin.programmeHosts(scheduleStore).first { $0.id == hostID }
        let host = admin.overview?.hosts.first { $0.hostID == hostID }
        let name = host?.displayName ?? programme?.name ?? hostID
        AdminPage(title: name) {
            VStack(spacing: 0) {
                infoRow(L10n.adminShows, (programme?.shows ?? []).joined(separator: ", ").nonEmpty ?? "—")
                infoRow(L10n.adminAccount, host?.linked == true ? L10n.adminLinkedOn(shortDate(host?.linkedAt)) : (host?.inviteExpiresAt != nil ? L10n.adminInvitePending(shortDate(host?.inviteExpiresAt)) : L10n.adminNoAccount))
                infoRow(L10n.adminWritesAs, name)
            }
            VStack(spacing: 0) {
                Button { newInvite(name) } label: {
                    adminRow(host?.linked == true || host?.inviteExpiresAt != nil ? L10n.adminSendNewInvite : L10n.adminCreateInvite, nil)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                if host?.linked == true {
                    Button { isConfirmingUnlink = true } label: {
                        HStack {
                            Text(L10n.adminUnlink).font(Theme.Typography.Heading.item).foregroundStyle(Theme.liveRed)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if host?.linked == true {
                Text(L10n.adminUnlinkNote)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            }
        }
        .confirmationDialog(L10n.adminUnlinkConfirm(name), isPresented: $isConfirmingUnlink, titleVisibility: .visible) {
            Button(L10n.adminUnlink, role: .destructive) {
                Task {
                    do {
                        try await admin.unlink(hostID: hostID)
                        Analytics.shared.track(.adminHostUnlinked)
                    } catch { toastError(error) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.adminUnlinkNote)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(Theme.Typography.Heading.item).foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 16)
            Text(value).font(Theme.Typography.Copy.body).foregroundStyle(Theme.mutedText).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline(0.08)).frame(height: 1) }
    }

    private func newInvite(_ name: String) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let invite = try await admin.createInvite(hostID: hostID, name: name)
                Analytics.shared.track(.adminInviteCreated(fromProgramme: true))
                path.append(.admin(.inviteReady(invite, name: name)))
            } catch { toastError(error) }
        }
    }
}

// MARK: - A5 Správci

struct AdminAdminsView: View {
    @ObservedObject private var admin = ChatAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var removing: ChatAdmin.Admin?

    var body: some View {
        AdminPage(title: L10n.adminAdmins) {
            adminBody(L10n.adminAdminsBody)
            VStack(spacing: 0) {
                ForEach(admin.overview?.admins ?? []) { item in
                    Button { if !item.isSuperadmin && !item.isMe { removing = item } } label: {
                        adminRow(
                            (item.nickname ?? "—") + (item.isMe ? " (\(L10n.adminYou))" : ""),
                            item.isSuperadmin ? L10n.adminSuperadmin : L10n.adminAdminSince(shortDate(item.adminSince)),
                            subtitleColor: item.isSuperadmin ? Theme.liveRed : Theme.subtleText,
                            chevron: !item.isSuperadmin && !item.isMe
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.reveal)
                }
            }
            .animation(Motion.smoothOut(Motion.medium), value: admin.overview?.admins.map(\.id))
            NavigationLink(value: ProfileView.Route.admin(.addAdmin)) {
                Text(L10n.adminAddAdmin)
                    .font(Theme.Typography.Copy.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.liveRed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .task { do { try await admin.reload() } catch { toastError(error) } }
        .confirmationDialog(L10n.adminRemoveAdmin(removing?.nickname ?? ""), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button(L10n.adminRemove, role: .destructive) {
                guard let user = removing else { return }
                Task {
                    do {
                        try await admin.setAdmin(user.userID, on: false)
                        Analytics.shared.track(.adminAdminsChanged(action: "remove"))
                    } catch { toastError(error) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

// MARK: - A6 Přidat správce

struct AdminAddAdminView: View {
    @ObservedObject private var admin = ChatAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ChatAdmin.FoundUser] = []
    @State private var selected: UUID?
    @State private var isWorking = false

    var body: some View {
        AdminPage(title: L10n.adminAddAdmin) {
            adminBody(L10n.adminAddAdminBody)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.mutedText)
                TextField(L10n.adminSearchPlaceholder, text: $query)
                    .font(Theme.Typography.Copy.reading)
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(spacing: 0) {
                ForEach(results) { user in
                    let disabled = user.registeredAt == nil || user.isAdmin
                    Button { selected = user.userID } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected == user.userID ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected == user.userID ? Theme.liveRed : Theme.mutedText)
                                .contentTransition(.symbolEffect(.replace))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.nickname ?? "—").font(Theme.Typography.Heading.item).foregroundStyle(Theme.textPrimary)
                                Text(user.isAdmin ? L10n.adminAlreadyAdmin : (user.registeredAt.map { L10n.slowriderSince(shortDate($0)) } ?? L10n.adminNotRegistered))
                                    .font(Theme.Typography.Copy.label)
                                    .foregroundStyle(Theme.subtleText)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline(0.08)).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .opacity(disabled ? 0.45 : 1)
                    .transition(.reveal)
                }
            }
            .animation(Motion.smoothOut(Motion.medium), value: results.map(\.id))
            PrimaryActionButton(title: L10n.adminMakeAdmin, isEnabled: selected != nil && !isWorking) { add() }
        }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = (try? await admin.findUsers(q)) ?? []
            if let selected, !results.contains(where: { $0.userID == selected }) { self.selected = nil }
        }
    }

    private func add() {
        guard let selected else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await admin.setAdmin(selected, on: true)
                Analytics.shared.track(.adminAdminsChanged(action: "add"))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch { toastError(error) }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
