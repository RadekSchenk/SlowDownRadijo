import SwiftUI

/// "Statistiky poslechu — jemná gamifikace" (Figma node 12300:796): today and
/// total listening plus the listener's place on the leaderboard. Sits between
/// the now-playing card and "Pořady"; a tap opens the Statistiky tab.
/// The leaderboard row appears once the community is big enough
/// (`ListeningStatsStore.communityUnlocked`); the numbers are always there.
struct StatsHomeBlock: View {
    @EnvironmentObject private var stats: ListeningStatsStore
    @ObservedObject private var loc = LocalizationManager.shared
    let onOpen: () -> Void

    var body: some View {
        let summary = stats.summary

        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // The home page's type scale (with the header's compact
                // player): section headings 19, item titles 17, text 14,
                // labels 13, figures 20–22.
                Text(L10n.statsHomeTitle)
                    .font(Theme.Typography.Heading.section)
                    .foregroundStyle(Theme.textPrimary)
                    .manropeLineHeight(26, fontSize: 19)

                HStack(spacing: 8) {
                    metric(label: L10n.today, seconds: summary.todaySeconds, isLive: stats.isMeasuring)
                    // On the first day of listening "Celkem" would just
                    // repeat "Dnes"; it joins once earlier days add to it
                    // (a minute's margin absorbs sync rounding).
                    if summary.totalSeconds >= summary.todaySeconds + 60 {
                        metric(label: L10n.statsTotal, seconds: summary.totalSeconds)
                            .transition(.reveal)
                    }
                }
                .animation(Motion.cardResize, value: summary.totalSeconds >= summary.todaySeconds + 60)

                // This week's place only (Statistiky 1.4), never "of N"; with
                // no place this week (few listeners, or not ranked) no row.
                if stats.communityUnlocked, let rank = summary.period(.week).rank {
                    HStack(spacing: 8) {
                        // One line in Figma; with a four-digit rank in a big
                        // community the pill grows, so this shrinks rather than wraps.
                        Text(L10n.statsLeaderboardWeekScope)
                            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.mutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        rankPill(rank)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func metric(label: String, seconds: Int, isLive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
                    .manropeLineHeight(18, fontSize: 13)
                if isLive {
                    // Counting right now (radio playing, stats on).
                    ListeningDot()
                        .transition(.opacity)
                }
            }
            .animation(Motion.smoothOut(Motion.fast), value: isLive)
            DurationText(seconds: seconds, numberSize: 20, unitSize: 13, lineHeight: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rankPill(_ rank: Int) -> some View {
        PopNumberText(
            text: "#\(rank)",
            font: Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline),
            color: Theme.liveRed
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.liveRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
