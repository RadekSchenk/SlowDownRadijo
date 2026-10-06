import SwiftUI

/// "2 h 14 m": big white numerals with small muted units, as in Figma's
/// stats cards (36/19 on the Statistiky screen, 24/14 on the home block).
struct DurationText: View {
    let seconds: Int
    let numberSize: CGFloat
    let unitSize: CGFloat
    let lineHeight: CGFloat

    var body: some View {
        let parts = StatsFormat.hoursAndMinutes(seconds: seconds)
        let gap = unitSize * 0.27 // the width of a space between number and unit
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            number(StatsFormat.number(parts.hours))
            unit("h").padding(.horizontal, gap)
            number("\(parts.minutes)")
            unit("m").padding(.leading, gap)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(parts.hours) h \(parts.minutes) m")
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.Manrope.extraBold(size: numberSize))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manropeLineHeight(lineHeight, fontSize: numberSize)
    }

    private func unit(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.Manrope.semibold(size: unitSize))
            .foregroundStyle(Theme.mutedText)
            .lineLimit(1)
    }
}

/// Section heading: ExtraBold 24 on a 30pt line.
struct StatsHeading: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
            .foregroundStyle(Theme.textPrimary)
            .manropeLineHeight(30, fontSize: 24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Body copy: Regular 14 on a 22pt line, muted.
struct StatsBodyText: View {
    let text: String
    var color: Color = Theme.mutedText

    init(_ text: String, color: Color = Theme.mutedText) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
            .foregroundStyle(color)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Dnes" / "Celkem" / community card: label, big duration, explanation.
struct StatsMetricCard: View {
    let label: String
    let seconds: Int
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
            DurationText(seconds: seconds, numberSize: 36, unitSize: 19, lineHeight: 44)
            StatsBodyText(description)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Last seven days as bars; the busiest day is highlighted in the action red.
struct WeeklyChartCard: View {
    let summary: ListeningStatsSummary

    private static let scaleHeight: CGFloat = 110
    private static let peakBarHeight: CGFloat = 105

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(StatsFormat.duration(seconds: summary.weekSeconds))
                    .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(L10n.statsWeekCaption)
                    .font(Theme.Typography.Manrope.regular(size: 11, relativeTo: .caption2))
                    .foregroundStyle(Theme.lavender)
            }

            if summary.weekSeconds == 0 {
                Text(L10n.statsEmptyChart)
                    .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 153)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(summary.bars) { bar in
                        column(for: bar)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func column(for bar: ListeningStatsSummary.DayBar) -> some View {
        let peak = summary.bars.map(\.seconds).max() ?? 0
        let height: CGFloat = bar.seconds > 0 && peak > 0
            ? max(2, CGFloat(bar.seconds) / CGFloat(peak) * Self.peakBarHeight)
            : 2
        return VStack(spacing: 8) {
            Text(StatsFormat.compactDuration(seconds: bar.seconds))
                .font(Theme.Typography.Manrope.semibold(size: 9, relativeTo: .caption2))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ZStack(alignment: .bottom) {
                Color.clear.frame(width: 20, height: Self.scaleHeight)
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 1,
                    bottomTrailingRadius: 1,
                    topTrailingRadius: 4,
                    style: .continuous
                )
                .fill(bar.isPeak ? Theme.liveRed : Theme.statsBarMuted)
                .opacity(bar.seconds > 0 ? 1 : 0.4)
                .frame(width: 20, height: height)
            }

            Text(bar.label)
                .font(Theme.Typography.Manrope.semibold(size: 11, relativeTo: .caption))
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The week's most-listened show: full-bleed artwork under a scrim, a
/// time-and-share badge on top, kicker, title and host at the bottom.
struct TopShowCard: View {
    let share: ListeningStatsSummary.ShowShare

    var body: some View {
        Color.clear
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .overlay { artwork }
            .overlay { scrim }
            .overlay(alignment: .topLeading) { badge }
            .overlay(alignment: .bottomLeading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var artwork: some View {
        if share.usesBundledHeroImage {
            Image("TheBestOfSlowDownHero")
                .resizable()
                .scaledToFill()
        } else {
            RemoteArtworkView(url: share.imageURL, cornerRadius: 0)
        }
    }

    /// Fades the photo into the page background so the caption stays legible.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.background.opacity(0), location: 0.35),
                .init(color: Theme.background.opacity(0.702), location: 0.65),
                .init(color: Theme.background.opacity(0.949), location: 0.90),
                .init(color: Theme.background, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var badge: some View {
        Text("\(StatsFormat.duration(seconds: share.seconds)) · \(StatsFormat.percent(share.fraction))")
            .font(Theme.Typography.Manrope.extraBold(size: 12))
            .foregroundStyle(Theme.liveRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.liveRed.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.liveRed, lineWidth: 1))
            .padding(16)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.statsTopShowKicker)
                .font(Theme.Typography.Manrope.bold(size: 9, relativeTo: .caption2))
                .foregroundStyle(Theme.mutedText)
            Text(share.name)
                .font(Theme.Typography.Manrope.extraBold(size: 20, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
                .manropeLineHeight(24, fontSize: 20)
            if let host = share.hostName {
                Text(host)
                    .font(Theme.Typography.Manrope.medium(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One of the other shows: name + host, time and share, and a thin share bar.
struct ShowShareRow: View {
    let share: ListeningStatsSummary.ShowShare

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(share.name)
                        .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                    if let host = share.hostName {
                        Text(host)
                            .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .caption))
                            .foregroundStyle(Theme.mutedText)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(StatsFormat.duration(seconds: share.seconds))
                        .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                    Text(StatsFormat.percent(share.fraction))
                        .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .caption))
                        .foregroundStyle(Theme.mutedText)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.divider)
                    Capsule()
                        .fill(Theme.mutedText)
                        .frame(width: max(3, proxy.size.width * CGFloat(share.fraction)))
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}
