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

/// "Tvůj Slowride" (Figma Profil M11): how long a Slowrider, time listened,
/// chat and voice messages, the three most listened shows. Numbers pop in
/// when they change.
struct SlowrideDashboard: View {
    let me: AccountService.Me
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        let summary = stats.summary
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.slowrideTitle)
                .font(Theme.Typography.Heading.section)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                tile(L10n.slowrideMember) {
                    numberAndUnit("\(daysMember)", L10n.slowrideDays(daysMember))
                }
                tile(L10n.slowrideListened) {
                    DurationText(seconds: summary.totalSeconds, numberSize: 22, unitSize: 13, lineHeight: 28)
                }
            }
            HStack(spacing: 8) {
                tile(L10n.slowrideChatMessages) { numberAndUnit("\(me.chatMessagesCount)", nil) }
                tile(L10n.slowrideVoiceMessages) { numberAndUnit("\(me.voiceMessagesCount)", nil) }
            }
            if !summary.shows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.slowrideTopShows)
                        .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                    ForEach(Array(summary.shows.prefix(3).enumerated()), id: \.element.id) { index, show in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                                .foregroundStyle(index == 0 ? Theme.liveRed : Theme.mutedText)
                                .frame(width: 14, alignment: .leading)
                            Text(show.name)
                                .font(Theme.Typography.Heading.item)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(StatsFormat.compactDuration(seconds: show.seconds))
                                .font(Theme.Typography.Copy.body)
                                .foregroundStyle(Theme.mutedText)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline(0.08)).frame(height: 1) }
                    }
                }
            }
        }
        .onAppear {
            Analytics.shared.track(.profileDashboardViewed(weeksMember: daysMember / 7))
        }
    }

    private var daysMember: Int {
        guard let since = me.registeredAt else { return 0 }
        let calendar = ScheduleStore.stationCalendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }

    private func tile<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func numberAndUnit(_ number: String, _ unit: String?) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            PopNumberText(text: number, font: Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title3), color: Theme.textPrimary)
            if let unit {
                Text(unit)
                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
            }
        }
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
