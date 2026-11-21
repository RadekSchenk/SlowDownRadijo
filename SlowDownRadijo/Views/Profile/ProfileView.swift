import SwiftUI

/// The Profil tab (Figma page "Profil", v3). Its states follow
/// `AccountService.state`:
///
/// * signed out — M2: "Staň se Slowriderem", the account's benefits and
///   Apple / Google / e‑mail
/// * writing without an account — M7: the nickname (locked), the Slowrider
///   card; changing the nickname asks to register (M8)
/// * registered — M1/M11: "Jsi součástí Slowriders od …", the "Tvůj
///   Slowride" dashboard, the chat and the account; the superadmin also gets
///   "Správa chatu" (M10, A1–A6)
///
/// Sub-screens are pushed inside the tab; sign-out and account deletion are
/// confirmed.
struct ProfileView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    /// Switches to the Statistiky tab (the row under the Slowrider card).
    var onOpenStats: () -> Void = {}
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var account = AccountService.shared
    @State private var path: [Route] = []
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var isShowingPrivacyPolicy = false
    @State private var registerReason: RegisterReason?

    enum Route: Hashable {
        case email, nickname, hiddenUsers, rules
        case admin(AdminRoute)
    }

    struct RegisterReason: Identifiable {
        let id: String
    }

    private static let privacyPolicyURL = URL(string: "https://slowdownradijo.cz/ochrana-osobnich-udaju/")!

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeaderView()
                        .padding(.top, AppHeaderView.topInset)

                    content
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, 36)
                        .animation(Motion.smoothOut(Motion.medium), value: stateKey)
                }
                .padding(.horizontal, 20)
                .scrollsToTopOnTabReselect()
            }
            .ignoresSafeArea(edges: .top)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .email: EmailSignInView(onSignedIn: { path.removeAll() })
                case .nickname: NicknameEditView()
                case .hiddenUsers: HiddenUsersView()
                case .rules: ChatRulesView()
                case .admin(let admin): adminDestination(admin)
                }
            }
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            SafariView(url: Self.privacyPolicyURL)
        }
        .sheet(item: $registerReason) { reason in
            RegisterSheet(reason: reason.id)
                .appTextSizeLimit()
        }
        .confirmationDialog(L10n.signOutConfirmTitle, isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button(L10n.profileSignOut, role: .destructive) {
                Task { await account.signOut() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.signOutConfirmBody)
        }
        .confirmationDialog(account.isSignedIn ? L10n.deleteAccountConfirmTitle : L10n.deleteDataConfirmTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(account.isSignedIn ? L10n.profileDeleteAccount : L10n.profileDeleteData, role: .destructive) { deleteAccount() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(account.isSignedIn ? L10n.deleteAccountConfirmBody : L10n.deleteDataConfirmBody)
        }
        .task { await account.refresh() }
    }

    /// Changes the content's animation when the kind of state changes.
    private var stateKey: String {
        switch account.state {
        case .loading: return "loading"
        case .signedOut: return "out"
        case .anonymous: return "anon"
        case .signedIn: return "in"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch account.state {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xxl)
        case .signedOut:
            signedOut.transition(.reveal)
        case .anonymous(let me):
            anonymous(me).transition(.reveal)
        case .signedIn(let method, let email, let me):
            Group {
                if let me, me.nickname == nil, !me.isHost {
                    NicknameSetupView()
                } else {
                    signedIn(method: method, email: email, me: me)
                }
            }
            .transition(.reveal)
        }
    }

    // MARK: - M2

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.profileTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                ProfileHeading(title: L10n.slowriderTitle, bodyText: L10n.slowriderBenefitsIntro, titleFont: Theme.Typography.Heading.hero)
                SlowriderBenefits()
                SignInButtons(onEmail: { path.append(.email) })
            }
            ProfileSection(title: L10n.profileOtherSection) {
                rulesRow
                ListDivider()
                privacyRow
            }
        }
        .onAppear { account.registrationSource = "profile_empty" }
    }

    // MARK: - M7

    private func anonymous(_ me: AccountService.Me) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.profileTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                identity(name: me.nickname ?? "", subtitle: L10n.profileWritingWithoutAccount, isHost: false)
                if me.blocked || me.mutedUntil.map({ $0 > Date() }) == true {
                    MutedBanner(mutedUntil: me.mutedUntil, blocked: me.blocked)
                }
                SlowriderCard(nickname: me.nickname ?? "") { registerReason = .init(id: "profile_card") }
            }
            ProfileSection(title: L10n.profileChatSection) {
                Button { registerReason = .init(id: "nickname_change") } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(L10n.profileNickname)
                            .font(Theme.Typography.Heading.item)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: Theme.Spacing.sm)
                        Text(me.nickname ?? "")
                            .font(Theme.Typography.Copy.body)
                            .foregroundStyle(Theme.mutedText)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.mutedText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.mutedText)
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.registerNicknameTitle)
                ListDivider()
                NavigationLink(value: Route.hiddenUsers) {
                    ProfileRow(title: L10n.profileHiddenUsers)
                }
                .buttonStyle(.plain)
                ListDivider()
                rulesRow
            }
            ProfileSection(title: L10n.profileOtherSection) {
                privacyRow
                ListDivider()
                Button { isConfirmingDelete = true } label: {
                    ProfileRow(title: L10n.profileDeleteData, showsChevron: false, isDestructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - M1 / M3 / M4 / M10 / M11

    private func signedIn(method: AccountService.SignInMethod?, email: String?, me: AccountService.Me?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.profileTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                if me == nil {
                    identity(
                        name: email ?? "",
                        subtitle: L10n.signedInWith(ProfileFormat.methodName(method)),
                        isHost: false
                    )
                }
                if let me, me.blocked || me.mutedUntil.map({ $0 > Date() }) == true {
                    MutedBanner(mutedUntil: me.mutedUntil, blocked: me.blocked)
                }
            }

            if let me {
                SlowrideDashboard(me: me, onOpenStats: onOpenStats)
            }

            if me?.isSuperadmin == true {
                ProfileSection(title: L10n.adminSection) {
                    NavigationLink(value: Route.admin(.moderators)) {
                        ProfileRow(title: L10n.adminModerators)
                    }
                    .buttonStyle(.plain)
                    ListDivider()
                    NavigationLink(value: Route.admin(.admins)) {
                        ProfileRow(title: L10n.adminAdmins)
                    }
                    .buttonStyle(.plain)
                }
            }

            ProfileSection(title: L10n.profileChatSection) {
                if me?.isHost == true {
                    ProfileRow(title: L10n.profileHostName, value: L10n.profileHostNameValue, showsChevron: false)
                } else {
                    NavigationLink(value: Route.nickname) {
                        ProfileRow(title: L10n.profileNickname, value: me?.nickname)
                    }
                    .buttonStyle(.plain)
                }
                ListDivider()
                NavigationLink(value: Route.hiddenUsers) {
                    ProfileRow(title: L10n.profileHiddenUsers)
                }
                .buttonStyle(.plain)
                ListDivider()
                rulesRow
            }

            ProfileSection(title: L10n.profileAccountSection) {
                ProfileRow(title: L10n.profileSignInMethod, value: ProfileFormat.methodName(method), showsChevron: false)
                ListDivider()
                Button { isConfirmingSignOut = true } label: {
                    ProfileRow(title: L10n.profileSignOut, showsChevron: false)
                }
                .buttonStyle(.plain)
                ListDivider()
                Button { isConfirmingDelete = true } label: {
                    ProfileRow(title: L10n.profileDeleteAccount, showsChevron: false, isDestructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func identity(name: String, subtitle: String, isHost: Bool, isSuperadmin: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(name)
                    .font(Theme.Typography.Heading.hero)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if isHost { ChatHostTag() }
                if isSuperadmin {
                    Text(L10n.adminSuperadmin)
                        .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
                        .foregroundStyle(Theme.liveRed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.liveRed.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Text(subtitle)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
        }
    }

    private var rulesRow: some View {
        NavigationLink(value: Route.rules) {
            ProfileRow(title: L10n.chatRulesTitle)
        }
        .buttonStyle(.plain)
    }

    private var privacyRow: some View {
        Button { isShowingPrivacyPolicy = true } label: {
            ProfileRow(title: L10n.settingsPrivacyPolicy)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func adminDestination(_ route: AdminRoute) -> some View {
        switch route {
        case .moderators: AdminModeratorsView(scheduleStore: scheduleStore)
        case .invite(let preselected): AdminInviteView(scheduleStore: scheduleStore, preselected: preselected, path: $path)
        case .inviteReady(let invite, let name): AdminInviteReadyView(invite: invite, name: name)
        case .moderator(let id): AdminModeratorDetailView(scheduleStore: scheduleStore, hostID: id, path: $path)
        case .admins: AdminAdminsView()
        case .addAdmin: AdminAddAdminView()
        }
    }

    private func deleteAccount() {
        let registered = account.isSignedIn
        Task {
            do {
                try await account.deleteAccount()
                Analytics.shared.track(.accountDeleted(registered: registered))
            } catch let error as AccountError {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }
}
