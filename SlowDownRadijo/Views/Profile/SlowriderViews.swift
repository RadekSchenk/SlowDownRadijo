import SwiftUI

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

/// Profil of a Slowrider (Figma "Explorace 1.3", M15): the member card
/// (nickname, since when, everything listened, chat and voice messages, days
/// on board), a row into Statistiky with today and this week, and the three
/// most listened shows. The card's darker wine look keeps Profil from
/// looking like Statistiky, whose coloured card shows today.
struct SlowrideDashboard: View {
    let me: AccountService.Me
    var onOpenStats: () -> Void = {}
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        let summary = stats.summary
        VStack(alignment: .leading, spacing: 16) {
            memberCard(summary)
            statsLink(summary)
            if !summary.shows.isEmpty {
                topShows(summary)
            }
        }
        .onAppear {
            Analytics.shared.track(.profileDashboardViewed(weeksMember: daysMember / 7))
        }
    }

    private func memberCard(_ summary: ListeningStatsSummary) -> some View {
        GlowCard(style: .member) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(me.isHost ? L10n.chatHostBadge.uppercased() : L10n.memberKicker)
                        .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(Color.glowLabel)
                    if me.isSuperadmin {
                        Text(L10n.adminSuperadmin.uppercased())
                            .font(Theme.Typography.Manrope.bold(size: 10, relativeTo: .caption2))
                            .tracking(1)
                            .foregroundStyle(Color.glowLabel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                }
                Text(me.chatName ?? "")
                    .font(Theme.Typography.Manrope.extraBold(size: 26, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let since = me.registeredAt {
                    Text(L10n.memberSince(ProfileFormat.date(since)))
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .accessibilityElement(children: .combine)

            Line()
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .frame(height: 1.5)
                .padding(.vertical, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.memberListened)
                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.glowLabel)
                DurationText(seconds: summary.totalSeconds, numberSize: 44, unitSize: 20, lineHeight: 52)
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: 12) {
                number("\(me.chatMessagesCount)", L10n.memberChat)
                number("\(me.voiceMessagesCount)", L10n.memberVoice)
                number("\(daysMember) \(L10n.slowrideDays(daysMember))", L10n.memberOnBoard)
            }
        }
    }

    private func number(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            PopNumberText(text: value, font: Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title3), color: Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func statsLink(_ summary: ListeningStatsSummary) -> some View {
        Button(action: onOpenStats) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.profileStatsLinkTitle(
                        StatsFormat.duration(seconds: summary.todaySeconds),
                        StatsFormat.duration(seconds: summary.weekSeconds)
                    ))
                    .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    Text(L10n.profileStatsLinkSubtitle)
                        .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                        .foregroundStyle(Theme.mutedText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func topShows(_ summary: ListeningStatsSummary) -> some View {
        StatsPanel(spacing: 16) {
            Text(L10n.slowrideTopShows)
                .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            let top = summary.shows.first?.seconds ?? 1
            ForEach(Array(summary.shows.prefix(3).enumerated()), id: \.element.id) { index, show in
                ShowBarRow(
                    share: show,
                    fraction: Double(show.seconds) / Double(max(top, 1)),
                    rank: index + 1,
                    isLeader: index == 0
                )
            }
        }
    }

    private var daysMember: Int {
        guard let since = me.registeredAt else { return 0 }
        let calendar = ScheduleStore.stationCalendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }
}

/// A horizontal line for dashed strokes (the member card's perforation).
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
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
