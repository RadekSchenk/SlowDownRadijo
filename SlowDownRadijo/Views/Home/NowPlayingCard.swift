import SwiftUI
import UIKit

/// The home screen's "Programme preview" (Figma "variation-3-card", node
/// 12318:5168): the current show's artwork as a 230 × 230 card, flanked
/// by `CardSideEqualizer` — no scrim, as no text sits on it any more. The title and host sit
/// below it (`HomeView`). The card is centred; the equalizer keeps Figma's
/// exact offsets from it, so on wider phones the extra room stays empty
/// rather than stretching.
struct NowPlayingCard: View {
    let artwork: UIImage?
    let isPlaying: Bool

    static let cardSize = CGSize(width: 230, height: 230)
    /// The coordinate space of the scrolling page content the card sits
    /// in — see `collapsesOnScroll()`.
    static let scrollContentSpace = "home.scrollContent"

    var body: some View {
        ZStack(alignment: .top) {
            CardSideEqualizer(isActive: isPlaying)
                // Figma: the "Equalizer" frame sits 45pt below the
                // preview's top edge, centred on the card.
                .padding(.top, 45)

            card
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.cardSize.height)
    }

    private var card: some View {
        artworkLayer
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkLayer: some View {
        if let artwork {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                .clipped()
                .transition(.opacity)
        } else {
            // Artwork still loading (or the show has none).
            Theme.statsCardRaised
        }
    }

}

extension NowPlayingCard {
    /// Like the cover art in Spotify: scrolling the page up shrinks the
    /// card and its equalizer, fades them out and lets them lag a little
    /// behind the scroll, so the show title and everything below slide
    /// over them. Scrolling back reverses it; pulling down to refresh
    /// leaves the card as it is. With Reduce Motion it only fades.
    ///
    /// The page must name its scroll content `scrollContentSpace`: the
    /// card's position in it, against its position in the scroll view,
    /// gives how far the page has scrolled.
    func collapsesOnScroll() -> some View {
        modifier(ScrollCollapse())
    }
}

private struct ScrollCollapse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Scroll distance over which the card goes from full size to gone.
    private static let distance: CGFloat = 240
    private static let smallestScale: CGFloat = 0.8
    /// Share of the scroll the card holds back: it moves at 60% speed.
    private static let lag: CGFloat = 0.4

    func body(content: Content) -> some View {
        content.visualEffect { [reduceMotion] view, proxy in
            let scrolled = proxy.frame(in: .named(NowPlayingCard.scrollContentSpace)).minY
                - proxy.frame(in: .scrollView).minY
            let travel = min(max(scrolled, 0), Self.distance)
            let progress = travel / Self.distance
            return view
                .scaleEffect(reduceMotion ? 1 : 1 - (1 - Self.smallestScale) * progress)
                .offset(y: reduceMotion ? 0 : travel * Self.lag)
                // Slow to start, so the card stays clear for the first
                // few points of scroll.
                .opacity(1 - pow(progress, 1.5))
        }
    }
}

/// The bars either side of `NowPlayingCard` (Figma "Equalizer", node
/// 12318:5183): five on each side, at the design's positions, opacities and
/// resting heights. Only the bars Figma shows are drawn — the ones behind
/// the card are at 0% opacity there.
///
/// Motion: the design's keyframe loop (17 steps, ease-in-out each) stopped
/// at every step and repeated a three-step pattern, so it read as choppy
/// and mechanical. Each bar now follows its own blend of three slow sine
/// waves at unrelated frequencies — continuous, never visibly repeating —
/// within the height range Figma gives that bar. Neighbouring bars are a
/// little out of phase, so movement ripples outward from the card, and
/// the bars next to the card move a touch more than the outer ones.
///
/// Starting and stopping playback eases the bars in and out of their
/// resting heights instead of jumping. With Reduce Motion they stay at rest.
struct CardSideEqualizer: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When `isActive` last changed — the start of the ease in or out.
    @State private var changedAt = Date.distantPast
    /// Keeps the timeline running while the bars settle after a stop.
    @State private var isSettling = false

    /// Figma frame: 322 × 140, 14pt in from each side of the 350pt preview.
    static let size = CGSize(width: 322, height: 140)
    private static let barWidth: CGFloat = 3
    private static let color = Color(hex: 0x8C839C)
    /// Ease in on play, out on pause.
    private static let blendDuration: TimeInterval = 0.8

    private struct Bar {
        /// Left edge within the 322pt frame.
        let x: CGFloat
        let opacity: Double
        /// Height in the design's first frame — the resting pose.
        let rest: CGFloat
        /// The shortest and tallest this bar gets in the design's loop.
        let low: CGFloat
        let peak: CGFloat
        /// 0 for the outermost bars, 1 for the ones next to the card.
        let nearCard: Double
    }

    private static let bars: [Bar] = [
        Bar(x: 0, opacity: 0.30, rest: 48, low: 17, peak: 52, nearCard: 0),
        Bar(x: 10.67, opacity: 0.30, rest: 94, low: 40, peak: 110, nearCard: 0.25),
        Bar(x: 21.33, opacity: 0.50, rest: 62, low: 34, peak: 74, nearCard: 0.5),
        Bar(x: 32, opacity: 0.50, rest: 110, low: 47, peak: 129, nearCard: 0.75),
        Bar(x: 42.67, opacity: 0.72, rest: 82, low: 30, peak: 89, nearCard: 1),
        Bar(x: 277.33, opacity: 0.72, rest: 104, low: 36, peak: 106, nearCard: 1),
        Bar(x: 288, opacity: 0.50, rest: 82, low: 32, peak: 93, nearCard: 0.75),
        Bar(x: 298.67, opacity: 0.50, rest: 112, low: 53, peak: 134, nearCard: 0.5),
        Bar(x: 309.33, opacity: 0.30, rest: 90, low: 44, peak: 108, nearCard: 0.25),
        Bar(x: 320, opacity: 0.30, rest: 64, low: 25, peak: 73, nearCard: 0),
    ]

    /// Per-bar wave settings, fixed so the motion is the same on every launch.
    private struct Wave {
        let frequency: Double
        let phase: Double
        let weight: Double
    }

    private static let waves: [[Wave]] = bars.indices.map { index in
        // Cheap, stable pseudo-random numbers in 0..<1 from the bar index.
        func random(_ salt: Double) -> Double {
            let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43_758.5453
            return value - value.rounded(.down)
        }
        // Ripple outward from the card: phase grows with distance from it.
        let ripple = (1 - bars[index].nearCard) * 1.1
        return [
            Wave(frequency: 0.42 + random(1) * 0.22, phase: ripple + random(2) * 6.28, weight: 0.55),
            Wave(frequency: 0.83 + random(3) * 0.35, phase: ripple * 1.6 + random(4) * 6.28, weight: 0.30),
            Wave(frequency: 1.47 + random(5) * 0.50, phase: random(6) * 6.28, weight: 0.15),
        ]
    }

    var body: some View {
        Group {
            if (isActive || isSettling) && !reduceMotion {
                TimelineView(.animation) { context in
                    bars(at: context.date)
                }
            } else {
                bars(at: nil)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
        .onChange(of: isActive) { _, active in
            changedAt = Date()
            guard !active else { return }
            isSettling = true
            Task {
                try? await Task.sleep(for: .seconds(Self.blendDuration))
                isSettling = false
            }
        }
    }

    /// `date` nil draws the resting pose.
    private func bars(at date: Date?) -> some View {
        let blend = date.map { intensity(at: $0) } ?? 0
        let time = date?.timeIntervalSinceReferenceDate ?? 0
        return Canvas { context, size in
            for index in Self.bars.indices {
                let bar = Self.bars[index]
                let height = Self.height(of: index, at: time, intensity: blend)
                let rect = CGRect(x: bar.x, y: (size.height - height) / 2, width: Self.barWidth, height: height)
                var barContext = context
                barContext.opacity = bar.opacity
                barContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.color))
            }
        }
    }

    /// 0 at rest, 1 while playing, eased in between.
    private func intensity(at date: Date) -> Double {
        let progress = min(max(date.timeIntervalSince(changedAt) / Self.blendDuration, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        return isActive ? eased : 1 - eased
    }

    private static func height(of index: Int, at time: TimeInterval, intensity: Double) -> CGFloat {
        let bar = bars[index]
        guard intensity > 0 else { return bar.rest }
        // Sum of the waves, -1…1, mapped to 0…1.
        let signal = waves[index].reduce(0.0) { sum, wave in
            sum + wave.weight * sin(2 * .pi * wave.frequency * time + wave.phase)
        }
        let level = (signal + 1) / 2
        // Bars by the card use all of their range, the outer ones a bit less.
        let reach = 0.85 + 0.15 * bar.nearCard
        let middle = (bar.low + bar.peak) / 2
        let moving = middle + (bar.peak - bar.low) * CGFloat((level - 0.5) * reach)
        return bar.rest + (moving - bar.rest) * CGFloat(intensity)
    }
}
