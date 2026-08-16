import SwiftUI

/// Shows how far the current programme block has progressed: start/end
/// clock times above a thin fill track, then "Pořad končí za 1h 29 min" /
/// "Další: <next show>" below it.
struct ShowProgressBar: View {
    @ObservedObject private var loc = LocalizationManager.shared

    let show: Show
    let progress: Double
    let remainingMinutes: Int
    let nextShow: Show?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(show.start)
                    .foregroundStyle(Theme.lavender)
                Spacer()
                Text(show.end)
                    .foregroundStyle(Theme.textPrimary)
            }
            .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline(0.08))

                    Capsule()
                        .fill(Theme.sunOrange)
                        .frame(width: max(6, proxy.size.width * progress))
                        .animation(.linear(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(remainingLabel)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)

                if let nextShow {
                    Text(L10n.next(nextShow.name))
                        .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var remainingLabel: String {
        guard remainingMinutes > 0 else { return L10n.showEndingNow }
        return L10n.showEndsIn(Self.formatted(minutes: remainingMinutes))
    }

    private static func formatted(minutes: Int) -> String {
        guard minutes >= 60 else { return L10n.minutesShort(minutes) }
        let hours = minutes / 60
        let remainder = minutes % 60
        return L10n.durationShort(hours: hours, minutes: remainder)
    }
}
