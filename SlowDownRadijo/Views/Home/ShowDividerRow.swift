import SwiftUI

/// Marks a show-block boundary inside the "Co hrálo" timeline: the show's
/// own start time (from the schedule, not any track's play time) + its
/// name, followed by a hairline divider.
struct ShowDividerRow: View {
    let show: Show

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                Text(show.start)
                    .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .frame(width: 44)

                Text(show.name)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Theme.lavender.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
