import SwiftUI

/// The Statistiky tab — Figma "Statistiky" (node 12299:834): page title,
/// today / total / everyone cards, the leaderboard, the last seven days as a
/// chart, time per show, and a short "what do the numbers mean".
///
/// Same page chrome as the other tabs: 20pt side margins, `AppHeaderView` on
/// top, 32pt between sections, each section closed by a divider.
struct StatsView: View {
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage(StatsConfig.enabledKey) private var statsEnabled = true

    var body: some View {
        let summary = stats.summary

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView()
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
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
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .refreshable { await stats.refreshAll(force: true) }
        .task { await stats.refreshAll() }
    }

    // MARK: - Overview

    private func overview(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.statsTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 36, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .manropeLineHeight(44, fontSize: 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatsBodyText(L10n.statsSubtitle)
            }

            if statsEnabled {
                StatsMetricCard(label: L10n.today, seconds: summary.todaySeconds, description: L10n.statsTodayDescription)
                StatsMetricCard(label: L10n.statsTotal, seconds: summary.totalSeconds, description: L10n.statsTotalDescription)
                StatsMetricCard(label: L10n.statsCommunityTitle, seconds: summary.communitySeconds, description: L10n.statsCommunityDescription)
            } else {
                disabledCard
            }

            ListDivider()
        }
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

    private func leaderboard(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            StatsHeading(L10n.statsLeaderboardTitle)

            if let rank = summary.rank {
                rankRow(rank: rank, of: summary.rankedListeners)
                StatsBodyText(L10n.statsLeaderboardDescription(count: StatsFormat.number(summary.rankedListeners)))
                Text(L10n.statsEncouragement)
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if stats.loadFailed {
                    StatsBodyText(L10n.statsOfflineNote, color: Theme.subtleText)
                }
            } else {
                rankPlaceholder(summary)
            }

            ListDivider()
        }
    }

    private func rankRow(rank: Int, of total: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("#\(rank)")
                        .font(Theme.Typography.Manrope.extraBold(size: 48, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.liveRed)
                        .manropeLineHeight(58, fontSize: 48)
                    Text(" \(L10n.statsRankOf) \(StatsFormat.number(total))")
                        .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.mutedText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text(L10n.statsLeaderboardScope)
                    .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.lavender)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Image("StatsTrophy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .foregroundStyle(Theme.liveRed)
                .frame(width: 48, height: 48)
                .background(Theme.liveRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            StatsBodyText(L10n.statsRankCalculating)
        }
    }

    // MARK: - Breakdown

    private func breakdown(_ summary: ListeningStatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                StatsHeading(L10n.statsTimelineTitle)
                Text(summary.weekRangeLabel)
                    .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
                WeeklyChartCard(summary: summary)
            }

            VStack(alignment: .leading, spacing: 14) {
                StatsHeading(L10n.statsShowsTitle)

                if let top = summary.shows.first {
                    Text(L10n.statsShowsContext(total: StatsFormat.duration(seconds: summary.weekSeconds)))
                        .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)

                    TopShowCard(share: top)

                    VStack(spacing: 0) {
                        let others = Array(summary.shows.dropFirst().prefix(7))
                        ForEach(Array(others.enumerated()), id: \.element.id) { index, share in
                            if index > 0 { ListDivider() }
                            ShowShareRow(share: share)
                        }
                    }
                } else {
                    StatsBodyText(L10n.statsEmptyShows)
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
