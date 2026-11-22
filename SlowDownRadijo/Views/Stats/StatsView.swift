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
        let rank = stats.communityUnlocked ? summary.rank.map { "#\($0)" } : nil
        return [
            .init(value: total, label: L10n.statsStripTotal),
            .init(value: rank ?? "–", label: L10n.statsStripRank, accent: rank != nil),
            .init(value: "\(summary.listeningDays) \(L10n.slowrideDays(summary.listeningDays))", label: L10n.statsStripDays),
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

    private func leaderboard(_ summary: ListeningStatsSummary) -> some View {
        StatsPanel(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.statsLeaderboardTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if stats.communityUnlocked, summary.rankedListeners > 0 {
                    Text("\(L10n.statsRankOf) \(StatsFormat.number(summary.rankedListeners))")
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                }
            }

            if !stats.communityUnlocked {
                StatsBodyText(L10n.statsLeaderboardLocked)
            } else if let rank = summary.rank {
                rankRow(rank: rank, of: summary.rankedListeners)
                if summary.aheadSeconds != nil || summary.behindSeconds != nil {
                    neighbours(summary, rank: rank)
                }
                Text(L10n.statsEncouragement)
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.statsLeaderboardAnonymous)
                    .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.mutedText.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                if stats.loadFailed {
                    StatsBodyText(L10n.statsOfflineNote, color: Theme.subtleText)
                }
            } else {
                rankPlaceholder(summary)
            }
        }
    }

    private func rankRow(rank: Int, of total: Int) -> some View {
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
                    Text(rank == 1 ? L10n.statsFirstPlace : L10n.statsTierLoyal)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func neighbours(_ summary: ListeningStatsSummary, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.statsNeighbours)
                .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
            NeighboursTrack(mine: summary.totalSeconds, rank: rank, ahead: summary.aheadSeconds, behind: summary.behindSeconds)
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
