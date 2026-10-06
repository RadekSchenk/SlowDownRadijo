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
                Text(L10n.statsHomeTitle)
                    .font(Theme.Typography.Manrope.bold(size: 19, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                    .manropeLineHeight(26, fontSize: 19)

                HStack(spacing: 8) {
                    metric(label: L10n.today, seconds: summary.todaySeconds)
                    metric(label: L10n.statsTotal, seconds: summary.totalSeconds)
                }

                if stats.communityUnlocked {
                    HStack(spacing: 8) {
                        // One line in Figma; with a four-digit rank in a big
                        // community the pill grows, so this shrinks rather than wraps.
                        Text(L10n.statsLeaderboardScope)
                            .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                            .foregroundStyle(Theme.mutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        rankPill(summary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func metric(label: String, seconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.mutedText)
                .manropeLineHeight(18, fontSize: 13)
            DurationText(seconds: seconds, numberSize: 24, unitSize: 14, lineHeight: 34)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rankPill(_ summary: ListeningStatsSummary) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            if let rank = summary.rank {
                Text("#\(rank)")
                    .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                    .foregroundStyle(Theme.liveRed)
                Text("  \(L10n.statsRankOf) \(StatsFormat.number(summary.rankedListeners))")
                    .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.mutedText)
            } else {
                Text("—")
                    .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.liveRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
