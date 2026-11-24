import SwiftUI

/// The Statistiky tab — Figma "Explorace 1.3 — Profil a Statistiky", S1:
/// today with the week in the coloured card, total / place / days, the
/// leaderboard around the listener (anonymous), time per show, everyone
/// together, and a short "what do the numbers mean".
///
/// Same page chrome as the other tabs: 20pt side margins, `AppHeaderView` on
/// top, 32pt between sections, each section closed by a divider.
struct StatsView: View {
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage(StatsConfig.enabledKey) private var statsEnabled = true
    /// The leaderboard's period: opens on this week every time.
    @State private var periodRaw = StatsPeriod.week.rawValue

    var body: some View {
        let summary = stats.summary

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView()
                    .padding(.top, AppHeaderView.topInset)

                VStack(alignment: .leading, spacing: 16) {
                    overview(summary)

                    if statsEnabled {
                        leaderboard(summary)
                        breakdown(summary)
                    }

                    explanation
                }
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 20)
            .contentColumn()
            .scrollsToTopOnTabReselect()
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .refreshable { await stats.refreshAll(force: true) }
        // First visit; later visits refresh from `RootTabView`, which keeps
        // the page alive between them.
        .task { await stats.refreshAll() }
    }

    // MARK: - Overview

    private func overview(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.statsTitle)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                    .manropeLineHeight(30, fontSize: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatsBodyText(L10n.statsSubtitle)
            }

            if statsEnabled {
                todayCard(summary)
                StatStrip(items: stripItems(summary))
                lastWeekCard(summary)
            } else {
                disabledCard
            }
        }
    }

    /// Figma S1: today in the coloured card, the week under it.
    private func todayCard(_ summary: ListeningStatsSummary) -> some View {
        GlowCard {
            HStack {
                Text(L10n.today)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.glowLabel)
                Spacer()
                if stats.isMeasuring {
                    HStack(spacing: 6) {
                        ListeningDot()
                        Text(L10n.statsLiveBadge)
                            .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption2))
                            .tracking(1.1)
                            .foregroundStyle(Color.glowLabel)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .transition(.opacity)
                }
            }
            DurationText(seconds: summary.todaySeconds, numberSize: 56, unitSize: 22, lineHeight: 64)
            Text(L10n.statsWeekTotal(StatsFormat.duration(seconds: summary.weekSeconds)))
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
            WeekBars(bars: summary.bars)
                .padding(.top, 4)
        }
        .animation(Motion.smoothOut(Motion.medium), value: stats.isMeasuring)
    }

    private func stripItems(_ summary: ListeningStatsSummary) -> [StatStrip.Item] {
        let hours = summary.totalSeconds / 3600
        let total = hours > 0 ? "\(StatsFormat.number(hours)) h" : StatsFormat.duration(seconds: summary.totalSeconds)
        // This week's place (Statistiky 1.4), and the run of days instead
        // of all the days: both a newcomer can top.
        let rank = stats.communityUnlocked ? summary.period(.week).rank.map { "#\($0)" } : nil
        return [
            .init(value: total, label: L10n.statsStripTotal),
            .init(value: rank ?? "–", label: L10n.statsPeriodWeekLabel, accent: rank != nil),
            .init(value: "\(summary.streakDays) \(L10n.slowrideDays(summary.streakDays))", label: L10n.statsStripStreak),
        ]
    }

    /// Shown instead of the numbers while measuring is switched off.
    private var disabledCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            StatsBodyText(L10n.statsDisabledMessage)
            PrimaryActionButton(title: L10n.statsEnableAction) {
                statsEnabled = true
                ListeningTracker.shared.enabledPreferenceChanged()
                Task { await stats.refreshAll(force: true) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Leaderboard

    /// Figma "Statistiky 1.4": the leaderboard for this week (the default:
    /// everyone starts from zero on Monday), this month or all time. The
    /// number of listeners is never shown; with too few in a period the
    /// card shows the listener's own time instead of a place.
    private func leaderboard(_ summary: ListeningStatsSummary) -> some View {
        let period = selectedPeriod
        let standing = summary.period(period)
        return StatsPanel(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(standing.rank == nil && stats.communityUnlocked ? L10n.statsPersonalTitle : L10n.statsLeaderboardTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if stats.communityUnlocked {
                    Text(Self.label(period))
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                }
            }

            if !stats.communityUnlocked {
                StatsBodyText(L10n.statsLeaderboardLocked)
            } else {
                PeriodPicker(selection: $periodRaw)

                if let rank = standing.rank {
                    rankRow(rank: rank, of: standing.ranked, period: period)
                    if standing.aheadSeconds != nil || standing.behindSeconds != nil {
                        neighbours(standing, rank: rank, period: period)
                    }
                    footer(period)
                } else if summary.totalSeconds == 0 || (stats.loadFailed && standing.seconds == 0) {
                    rankPlaceholder(summary)
                } else if period != .all && standing.isOpen && standing.seconds < Self.rankedSeconds {
                    progressToRank(standing, period: period)
                    footer(period)
                } else {
                    personal(standing, period: period)
                    footer(period)
                }
                if stats.loadFailed && summary.totalSeconds > 0 {
                    StatsBodyText(L10n.statsOfflineNote, color: Theme.subtleText)
                }
            }
        }
        .animation(Motion.smoothOut(Motion.medium), value: periodRaw)
    }

    /// 10 minutes in a period put a listener on its leaderboard (019).
    private static let rankedSeconds = 600

    private var selectedPeriod: StatsPeriod {
        StatsPeriod(rawValue: periodRaw) ?? .week
    }

    private static func label(_ period: StatsPeriod) -> String {
        switch period {
        case .week: L10n.statsPeriodWeekLabel
        case .month: L10n.statsPeriodMonthLabel
        case .all: L10n.statsPeriodAllLabel
        }
    }

    private func footer(_ period: StatsPeriod) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(period == .week ? L10n.statsPeriodFooterWeek : period == .month ? L10n.statsPeriodFooterMonth : L10n.statsPeriodFooterAll)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.statsLeaderboardAnonymous)
                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rankRow(rank: Int, of total: Int, period: StatsPeriod) -> some View {
        HStack(alignment: .center, spacing: 14) {
            PopNumberText(
                text: "#\(rank)",
                font: Theme.Typography.Manrope.extraBold(size: 48, relativeTo: .largeTitle),
                color: Theme.liveRed
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            VStack(alignment: .leading, spacing: 6) {
                if let tier = StatsTier.label(rank: rank, of: total) {
                    Text(L10n.statsTierTop(tier))
                        .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption2))
                        .tracking(1)
                        .foregroundStyle(Color.glowLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.liveRed.opacity(0.18), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.liveRed.opacity(0.5), lineWidth: 1))
                }
                if rank == 1 || StatsTier.isLoyal(rank: rank, of: total) {
                    Text(rank == 1 ? L10n.statsFirstPlace
                         : period == .week ? L10n.statsTierLoyalWeek
                         : period == .month ? L10n.statsTierLoyalMonth : L10n.statsTierLoyal)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func neighbours(_ standing: PeriodStanding, rank: Int, period: StatsPeriod) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(period == .week ? L10n.statsNeighboursWeek : period == .month ? L10n.statsNeighboursMonth : L10n.statsNeighbours)
                .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
            NeighboursTrack(mine: standing.seconds, rank: rank, ahead: standing.aheadSeconds, behind: standing.behindSeconds)
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Figma R4: not on this period's leaderboard yet, and how little is
    /// missing (only where the period has places at all).
    private func progressToRank(_ standing: PeriodStanding, period: StatsPeriod) -> some View {
        let minutes = min(standing.seconds / 60, 9)
        return VStack(alignment: .leading, spacing: 10) {
            Text(period == .week ? L10n.statsToRankWeek(10 - minutes) : L10n.statsToRankMonth(10 - minutes))
                .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.liveRed)
                        .frame(width: proxy.size.width * CGFloat(standing.seconds) / CGFloat(Self.rankedSeconds))
                }
            }
            .frame(height: 6)
            Text(L10n.statsToRankProgress(minutes))
                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Figma R7: no place to show (too few listeners in the period, or not
    /// ranked): the listener's own time and how it compares with the
    /// period before — never with others.
    private func personal(_ standing: PeriodStanding, period: StatsPeriod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DurationText(seconds: standing.seconds, numberSize: 40, unitSize: 18, lineHeight: 48)
            Text(period == .week ? L10n.statsPersonalWeek : period == .month ? L10n.statsPersonalMonth : L10n.statsPersonalAll)
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
            if let comparison = Self.comparison(standing, period: period) {
                Text(comparison)
                    .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.glowLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.liveRed.opacity(0.18), in: Capsule())
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private static func comparison(_ standing: PeriodStanding, period: StatsPeriod) -> String? {
        guard period != .all, let previous = standing.previousSeconds, previous > 0 else { return nil }
        let difference = standing.seconds - previous
        let amount = StatsFormat.duration(seconds: abs(difference))
        if abs(difference) < 60 {
            return period == .week ? L10n.statsSameAsLastWeek : L10n.statsSameAsLastMonth
        }
        if difference > 0 {
            return period == .week ? L10n.statsMoreThanLastWeek(amount) : L10n.statsMoreThanLastMonth(amount)
        }
        return period == .week ? L10n.statsLessThanLastWeek(amount) : L10n.statsLessThanLastMonth(amount)
    }

    /// Figma R5: on Monday and Tuesday, how last week went — with the place
    /// only in the top ten of a week that had places.
    @ViewBuilder
    private func lastWeekCard(_ summary: ListeningStatsSummary) -> some View {
        let weekday = ListeningStatsStore.pragueCalendar.component(.weekday, from: AppClock.now)
        if (weekday == 2 || weekday == 3), summary.lastWeekSeconds >= Self.rankedSeconds {
            let place = summary.lastWeekRank.flatMap { $0 <= 10 ? $0 : nil }
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.statsLastWeekTitle)
                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.glowLabel)
                Text(place.map(L10n.statsLastWeekPlace) ?? L10n.statsWithRadio(StatsFormat.duration(seconds: summary.lastWeekSeconds)))
                    .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                if place != nil {
                    Text(L10n.statsWithRadio(StatsFormat.duration(seconds: summary.lastWeekSeconds)))
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.glowLabel)
                }
                Text(place != nil ? L10n.statsLastWeekGreat : L10n.statsLastWeekNew)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(hex: 0x3B1F7A), Color(hex: 0x7A1838)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        }
    }

    /// No rank to show yet — says why instead of leaving a hole.
    @ViewBuilder
    private func rankPlaceholder(_ summary: ListeningStatsSummary) -> some View {
        if stats.loadFailed {
            StatsBodyText(L10n.statsRankFailed)
            SecondaryActionButton(title: L10n.statsRetry) {
                Task { await stats.refreshAll(force: true) }
            }
        } else if summary.totalSeconds == 0 {
            StatsBodyText(L10n.statsRankNoListening)
        } else if summary.totalSeconds < 60 {
            StatsBodyText(L10n.statsRankNeedsMinute)
        } else {
            // Still working it out (library P15 — shimmer on text).
            ShimmerText(
                text: L10n.statsRankCalculating,
                font: Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline),
                base: Theme.mutedText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Breakdown

    private func breakdown(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StatsPanel(spacing: 16) {
                Text(L10n.statsShowsTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                if let top = summary.shows.first {
                    ForEach(Array(summary.shows.prefix(8)), id: \.id) { share in
                        ShowBarRow(
                            share: share,
                            fraction: Double(share.seconds) / Double(max(top.seconds, 1)),
                            isLeader: share.id == top.id
                        )
                    }
                } else {
                    StatsBodyText(L10n.statsEmptyShows)
                }
            }

            if stats.communityUnlocked {
                StatsPanel(spacing: 4) {
                    Text(L10n.statsCommunityTitle)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                    DurationText(seconds: summary.communitySeconds, numberSize: 30, unitSize: 16, lineHeight: 38)
                    StatsBodyText(L10n.statsCommunityDescription)
                }
            }

            ListDivider()
        }
    }

    // MARK: - Explanation

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsHeading(L10n.statsExplainTitle)
            StatsBodyText(L10n.statsExplainBody)
            Text(L10n.statsPrivacyNote)
                .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.subtleText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Týden · Měsíc · Celkem (Figma "Statistiky 1.4").
private struct PeriodPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases) { period in
                let isSelected = selection == period.rawValue
                Button {
                    selection = period.rawValue
                } label: {
                    Text(Self.title(period))
                        .font(isSelected
                              ? Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)
                              : Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color(hex: 0x3A2F5C) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private static func title(_ period: StatsPeriod) -> String {
        switch period {
        case .week: L10n.statsPeriodWeek
        case .month: L10n.statsPeriodMonth
        case .all: L10n.statsPeriodAll
        }
    }
}
