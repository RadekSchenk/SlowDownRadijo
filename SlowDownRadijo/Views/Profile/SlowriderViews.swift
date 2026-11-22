import SwiftUI
import UIKit

/// The account's benefits on the empty Profil (Figma Profil M2): managing the
/// profile and the nickname, stats that move with the account, more to come.
/// The rows reveal one after another the first time they appear.
struct SlowriderBenefits: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    private var items: [(String, String)] {
        [
            (L10n.benefitProfileTitle, L10n.benefitProfileBody),
            (L10n.benefitStatsTitle, L10n.benefitStatsBody),
            (L10n.benefitMoreTitle, L10n.benefitMoreBody),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index < shown {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.liveRed)
                            .frame(width: 22, height: 22)
                            .background(Theme.liveRed.opacity(0.16), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                                .foregroundStyle(Theme.textPrimary)
                            Text(item.1)
                                .font(Theme.Typography.Copy.body)
                                .foregroundStyle(Theme.mutedText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .transition(.reveal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            guard shown == 0 else { return }
            if reduceMotion { shown = items.count; return }
            for index in 1...items.count {
                try? await Task.sleep(for: .milliseconds(index == 1 ? 150 : 120))
                withAnimation(Motion.smoothOut(Motion.medium)) { shown = index }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Staň se Slowriderem" on the Profil of someone who writes without an
/// account (Figma Profil M7).
struct SlowriderCard: View {
    let nickname: String
    let onRegister: () -> Void

    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.slowriderTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.slowriderCardBody(nickname))
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryActionButton(title: L10n.slowriderRegister, action: onRegister)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Profil of a Slowrider (Figma "Explorace — Profil v2", P1): laid out like a
/// profile, not like Statistiky — the nickname large, a row of numbers
/// (listened, chat messages, voice messages, days on board), "Upravit
/// přezdívku" and "Moje statistiky", and the three favourite shows as a
/// grid of photos.
struct SlowrideDashboard: View {
    let me: AccountService.Me
    var onOpenStats: () -> Void = {}
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        let summary = stats.summary
        VStack(alignment: .leading, spacing: 20) {
            header
            counters(summary)
            buttons
            if !summary.shows.isEmpty {
                favourites(summary)
            }
        }
        .onAppear {
            Analytics.shared.track(.profileDashboardViewed(weeksMember: daysMember / 7))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(me.chatName ?? "")
                    .font(Theme.Typography.Manrope.extraBold(size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                pill(me.isHost ? L10n.chatHostBadge.uppercased() : L10n.memberKicker)
                if me.isSuperadmin {
                    pill(L10n.adminSuperadmin.uppercased())
                }
            }
            if let since = me.registeredAt {
                Text(L10n.slowriderSinceLong(ProfileFormat.date(since)))
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.Manrope.bold(size: 10, relativeTo: .caption2))
            .tracking(1.2)
            .foregroundStyle(Color.glowLabel)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.liveRed.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize()
    }

    /// Like a profile's posts / followers row: numbers in a line, no boxes.
    private func counters(_ summary: ListeningStatsSummary) -> some View {
        let hours = summary.totalSeconds / 3600
        let listened = hours > 0 ? "\(StatsFormat.number(hours)) h" : StatsFormat.duration(seconds: summary.totalSeconds)
        return HStack(spacing: 0) {
            counter(listened, L10n.memberListenedShort)
            counter("\(me.chatMessagesCount)", L10n.memberMessages(me.chatMessagesCount))
            counter("\(me.voiceMessagesCount)", L10n.memberVoiceMessages(me.voiceMessagesCount))
            counter("\(daysMember)", L10n.slowrideDays(daysMember))
        }
        .padding(.top, 2)
    }

    private func counter(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            PopNumberText(text: value, font: Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title3), color: Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if !me.isHost {
                NavigationLink(value: ProfileView.Route.nickname) {
                    buttonLabel(L10n.profileEditNickname)
                }
                .buttonStyle(.plain)
            }
            Button(action: onOpenStats) {
                buttonLabel(L10n.profileMyStats)
            }
            .buttonStyle(.plain)
        }
    }

    private func buttonLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
    }

    /// The three favourite shows as photos, like a profile's grid.
    private func favourites(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.profileFavouriteShows)
                .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    if index < summary.shows.count {
                        tile(summary.shows[index], rank: index + 1)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tile(_ share: ListeningStatsSummary.ShowShare, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { ShowShareArtwork(share: share) }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(hex: 0x120E25).opacity(0.85)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .topLeading) {
                    Text("\(rank)")
                        .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(rank == 1 ? Theme.liveRed : Color(hex: 0x120E25).opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(StatsFormat.compactDuration(seconds: share.seconds))
                        .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(share.name)
                .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var daysMember: Int {
        guard let since = me.registeredAt else { return 0 }
        let calendar = ScheduleStore.stationCalendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: AppClock.now)).day ?? 0
        return max(1, days + 1)
    }
}

/// A show's photo from its listening share: bundled, else from the web,
/// else the brand placeholder (as `ShowArtworkView`), filling its frame.
struct ShowShareArtwork: View {
    let share: ListeningStatsSummary.ShowShare

    var body: some View {
        Group {
            if let name = share.artworkName, UIImage(named: name) != nil {
                Image(name).resizable().scaledToFill()
            } else if let url = share.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        ShowArtworkPlaceholder(cornerRadius: 0)
                    }
                }
            } else {
                ShowArtworkPlaceholder(cornerRadius: 0)
            }
        }
        .accessibilityHidden(true)
    }
}


/// "Přezdívku změníš s účtem" and the Slowrider card's sign-up (Figma
/// Profil M8): Apple / Google / e-mail, keeping the nickname and stats.
struct RegisterSheet: View {
    let reason: String

    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ProfileHeading(
                        title: reason == "nickname_change" ? L10n.registerNicknameTitle : L10n.slowriderTitle,
                        bodyText: L10n.registerBody(account.me?.nickname ?? ""),
                        titleFont: Theme.Typography.Heading.hero
                    )
                    SignInButtons(onEmail: { path.append(1) })
                    Button(L10n.chatNotNow) { dismiss() }
                        .font(Theme.Typography.Copy.link)
                        .foregroundStyle(Theme.mutedText)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .background(Theme.statsCard.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { _ in
                EmailSignInView(onSignedIn: { path.removeAll() })
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.statsCard)
        .onAppear {
            account.registrationSource = reason
            Analytics.shared.track(.registrationPromptShown(reason: reason))
        }
        .onChange(of: account.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }
}
