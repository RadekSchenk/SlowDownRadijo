import SwiftUI

/// The coloured lead cards of Statistiky (Figma "Explorace 1.3", S1) and
/// Profil (M15): a deep gradient with a soft red glow. Statistiky's is
/// violet with the glow top right; the Slowrider card is darker, wine to
/// night, with the glow bottom left, so the two tabs never look alike.
struct GlowCard<Content: View>: View {
    enum Style { case stats, member }

    var style: Style = .stats
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(style == .member ? 22 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .clipShape(RoundedRectangle(cornerRadius: style == .member ? 24 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: style == .member ? 24 : 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(style == .member ? 0.14 : 0.10), lineWidth: 1)
            }
    }

    private var background: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: colors, startPoint: start, endPoint: end)
                Circle()
                    .fill(Color(hex: 0xFF3B4E).opacity(style == .member ? 0.35 : 0.4))
                    .frame(width: 220, height: 220)
                    .blur(radius: 70)
                    .position(
                        x: style == .member ? 10 : proxy.size.width - 30,
                        y: style == .member ? proxy.size.height + 10 : 10
                    )
            }
        }
    }

    private var colors: [Color] {
        switch style {
        case .stats: return [Color(hex: 0x4A2A86), Color(hex: 0x2A1D52), Color(hex: 0x1A1535)]
        case .member: return [Color(hex: 0x3A1430), Color(hex: 0x221437), Color(hex: 0x150F28)]
        }
    }
    private var start: UnitPoint { style == .member ? .bottomLeading : .topLeading }
    private var end: UnitPoint { style == .member ? .topTrailing : .bottomTrailing }
}

/// A plain dark card: `statsCardRaised`, 20pt corners.
struct StatsPanel<Content: View>: View {
    var spacing: CGFloat = 14
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The pale pink of labels on the coloured cards.
extension Color {
    static let glowLabel = Color(hex: 0xFFD0D5)
}

/// The last seven days inside a coloured card: hours above each bar, the
/// busiest day in the station red, today labelled "Dnes".
struct WeekBars: View {
    let bars: [ListeningStatsSummary.DayBar]

    private static let maxBar: CGFloat = 62

    var body: some View {
        let peak = bars.map(\.seconds).max() ?? 0
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                let isToday = index == bars.count - 1
                let height = bar.seconds > 0 && peak > 0
                    ? max(6, CGFloat(bar.seconds) / CGFloat(peak) * Self.maxBar)
                    : 4
                VStack(spacing: 6) {
                    PopNumberText(
                        text: StatsFormat.compactDuration(seconds: bar.seconds),
                        font: Theme.Typography.Manrope.bold(size: 10, relativeTo: .caption2),
                        color: bar.isPeak ? Theme.textPrimary : Theme.mutedText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(bar.isPeak ? Theme.liveRed : Color.white.opacity(0.22))
                        .frame(height: height)
                        .animation(Motion.cardResize, value: height)
                    Text(isToday ? L10n.today : bar.label)
                        .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption))
                        .foregroundStyle(isToday ? Theme.textPrimary : Theme.mutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bars.map { "\($0.label) \(StatsFormat.duration(seconds: $0.seconds))" }.joined(separator: ", "))
    }
}

/// Three numbers side by side with hairlines between them.
struct StatStrip: View {
    struct Item: Identifiable {
        let value: String
        let label: String
        var accent = false
        var id: String { label }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 36)
                }
                VStack(spacing: 2) {
                    PopNumberText(
                        text: item.value,
                        font: Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2),
                        color: item.accent ? Theme.liveRed : Theme.textPrimary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Text(item.label)
                        .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A thin share bar; the leader's in the station red.
struct ShareBar: View {
    let fraction: Double
    var accent = false
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(accent ? Theme.liveRed : Theme.mutedText.opacity(0.6))
                    .frame(width: max(height, proxy.size.width * CGFloat(min(max(fraction, 0), 1))))
                    .animation(Motion.cardResize, value: fraction)
            }
        }
        .frame(height: height)
    }
}

/// One show with name, host, time and a bar relative to the most listened.
struct ShowBarRow: View {
    let share: ListeningStatsSummary.ShowShare
    let fraction: Double
    var rank: Int?
    var isLeader = false

    var body: some View {
        HStack(spacing: 14) {
            if let rank {
                Text("\(rank)")
                    .font(Theme.Typography.Manrope.extraBold(size: rank == 1 ? 32 : 24, relativeTo: .title2))
                    .foregroundStyle(rank == 1 ? Theme.liveRed : Theme.mutedText)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(share.name)
                            .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        if rank == nil, let host = share.hostName {
                            Text(host)
                                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                                .foregroundStyle(Theme.mutedText)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    PopNumberText(
                        text: StatsFormat.duration(seconds: share.seconds),
                        font: Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline),
                        color: isLeader ? Theme.textPrimary : Theme.mutedText
                    )
                }
                ShareBar(fraction: fraction, accent: isLeader)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The places around the listener (S1): the place just above, the
/// listener, the place just below, spaced by their listening time. Neighbours, not rivals: no gaps to close.
struct NeighboursTrack: View {
    let mine: Int
    let rank: Int
    let ahead: Int?
    let behind: Int?

    var body: some View {
        let values = [behind, mine, ahead].compactMap { $0 }
        let lo = Double(values.min() ?? mine), hi = Double(values.max() ?? mine)
        let span = max(hi - lo, 1)
        GeometryReader { proxy in
            let width = proxy.size.width
            let x: (Int) -> CGFloat = { value in
                values.count < 2 ? width / 2 : 10 + CGFloat((Double(value) - lo) / span) * (width - 20)
            }
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.22)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 4)
                    .clipShape(Capsule())
                    .offset(y: 37)
                if let behind {
                    marker(x: x(behind), width: width, rank: "#\(rank + 1)", time: behind)
                }
                if let ahead {
                    marker(x: x(ahead), width: width, rank: "#\(rank - 1)", time: ahead)
                }
                // You: above the line.
                Text("\(L10n.statsYou) · \(StatsFormat.duration(seconds: mine))")
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
                    .position(x: clamp(x(mine), width: width, half: 60), y: 12)
                Circle()
                    .fill(Theme.liveRed)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                    .frame(width: 18, height: 18)
                    .position(x: x(mine), y: 39)
            }
        }
        .frame(height: 90)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.statsNeighbours)
    }

    private func marker(x: CGFloat, width: CGFloat, rank: String, time: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x6F6694))
                .overlay(Circle().strokeBorder(Theme.statsCardRaised, lineWidth: 2))
                .frame(width: 12, height: 12)
                .position(x: x, y: 39)
            VStack(spacing: 2) {
                Text(rank).font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                Text(StatsFormat.duration(seconds: time)).font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
            }
            .foregroundStyle(Theme.mutedText)
            .fixedSize()
            .position(x: clamp(x, width: width, half: 34), y: 70)
        }
    }

    private func clamp(_ x: CGFloat, width: CGFloat, half: CGFloat) -> CGFloat {
        min(max(x, half), width - half)
    }
}

/// "TOP 1 %" — the smallest of 10 places, 1, 5, 10, 25 % that the rank fits
/// in; nothing for the bottom half.
enum StatsTier {
    static func label(rank: Int, of total: Int) -> String? {
        guard total > 0, rank >= 1 else { return nil }
        if rank <= 10 && total > 20 { return "10" }
        let share = Double(rank) / Double(total)
        for limit in [0.01, 0.05, 0.10, 0.25, 0.5] where share <= limit {
            return "\(Int(limit * 100)) %"
        }
        return nil
    }

    static func isLoyal(rank: Int, of total: Int) -> Bool {
        total > 0 && Double(rank) / Double(total) <= 0.10
    }
}
