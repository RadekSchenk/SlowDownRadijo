import SwiftUI

/// The Profil tab (Figma page "Profil"): signing in, the nickname, the
/// account. Its states follow `AccountService.state`:
///
/// * signed out — M2: "Přihlas se a piš do chatu" + Apple / Google / e‑mail
/// * signed in without a nickname — R1: "Ještě přezdívka"
/// * signed in — M1 (listener), M3 (DJ), M4 (muted or blocked banner)
///
/// Sub-screens (e‑mail code, nickname, hidden listeners, chat rules) are
/// pushed inside the tab; sign-out and account deletion are confirmed.
struct ProfileView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var account = AccountService.shared
    @State private var path: [Route] = []
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var isShowingPrivacyPolicy = false

    enum Route: Hashable {
        case email, nickname, hiddenUsers, rules
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
                }
            }
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            SafariView(url: Self.privacyPolicyURL)
        }
        .confirmationDialog(L10n.signOutConfirmTitle, isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button(L10n.profileSignOut, role: .destructive) {
                Task { await account.signOut() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.signOutConfirmBody)
        }
        .confirmationDialog(L10n.deleteAccountConfirmTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(L10n.profileDeleteAccount, role: .destructive) { deleteAccount() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteAccountConfirmBody)
        }
        .task { await account.refresh() }
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
            signedOut
        case .signedIn(let method, let email, let me):
            if let me, me.nickname == nil, !me.isHost {
                NicknameSetupView()
            } else {
                signedIn(method: method, email: email, me: me)
            }
        }
    }

    // MARK: - M2

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.profileTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                ProfileHeading(title: L10n.profileSignInTitle, bodyText: L10n.profileSignInBody, titleFont: Theme.Typography.Heading.hero)
                SignInButtons(onEmail: { path.append(.email) })
            }
            ProfileSection(title: L10n.profileOtherSection) {
                rulesRow
                ListDivider()
                Button { isShowingPrivacyPolicy = true } label: {
                    ProfileRow(title: L10n.settingsPrivacyPolicy)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - M1 / M3 / M4

    private func signedIn(method: AccountService.SignInMethod?, email: String?, me: AccountService.Me?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.profileTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(me?.chatName ?? email ?? "")
                            .font(Theme.Typography.Heading.hero)
                            .foregroundStyle(Theme.textPrimary)
                        if me?.isHost == true {
                            Text("DJ")
                                .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
                                .foregroundStyle(Theme.liveRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Theme.liveRed.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    Text(me?.isHost == true ? L10n.profileHostRole : L10n.signedInWith(ProfileFormat.methodName(method)))
                        .font(Theme.Typography.Copy.body)
                        .foregroundStyle(Theme.mutedText)
                }

                if let me, me.blocked || me.mutedUntil.map({ $0 > Date() }) == true {
                    MutedBanner(mutedUntil: me.mutedUntil, blocked: me.blocked)
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

    private var rulesRow: some View {
        NavigationLink(value: Route.rules) {
            ProfileRow(title: L10n.chatRulesTitle)
        }
        .buttonStyle(.plain)
    }

    private func deleteAccount() {
        Task {
            do {
                try await account.deleteAccount()
            } catch let error as AccountError {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }
}
