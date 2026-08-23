import SwiftUI

/// Marks a show-block boundary inside the "Co hrálo" timeline: the show's
/// own start time (from the schedule, not any track's play time) + a
/// "Začátek pořadu" kicker over its name, centered (not left-aligned like
/// a normal history row's text), followed by a hairline — same time-column
/// + trailing-hairline shape as `HistoryRowView`, so the boundary reads as
/// part of the same flat list rather than a visually distinct element.
struct ShowDividerRow: View {
    let show: Show

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(show.start)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .frame(width: 44, height: 44, alignment: .center)

                VStack(alignment: .center, spacing: 4) {
                    Text(L10n.showStartingKicker)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                        .foregroundStyle(Theme.lavender)
                    Text(show.name)
                        .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .headline))
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // See HistoryRowView — 12pt on both sides matches the Figma
            // row gap and keeps the hairline centered between rows, color
            // matches the Figma "Line 5" asset (`Theme.lavender` at 20%).
            Rectangle()
                .fill(Theme.lavender.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 12)
        }
    }
}
