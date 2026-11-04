import SwiftUI
import UIKit

/// The home screen's "Programme preview" (Figma "variation-3-card", node
/// 12341:1649): the current show's artwork as a 230 × 230 card, flanked
/// by `CardSideEqualizer` — no scrim, as no text sits on it any more. The
/// title, host and song sit above it, the player controls below
/// (`HomeView`). The card is centred; the equalizer keeps Figma's
/// exact offsets from it, so on wider phones the extra room stays empty
/// rather than stretching.
struct NowPlayingCard: View {
    let artwork: UIImage?
    let isPlaying: Bool

    static let cardSize = CGSize(width: 230, height: 230)

    var body: some View {
        card
            .frame(maxWidth: .infinity)
            .frame(height: Self.cardSize.height)
            // Behind the card and never wider than the page: as a
            // background it can't widen the layout (it did, pushing the
            // whole page out to the screen's edges). Figma: the
            // "Equalizer" frame sits 45pt below the preview's top edge,
            // centred on the card.
            .background(alignment: .top) {
                CardSideEqualizer(isActive: isPlaying)
                    .padding(.top, 45)
            }
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

/// The waveform either side of `NowPlayingCard`: nine thin bars a side,
/// growing up and down from the card's middle line, tall next to the card
/// and smaller and fainter towards the page's edges — a sound wave
/// spreading out from the show. In the host line's colour
/// (`Theme.mutedText`), plain, no glow; it stays within the page's
/// content width.
///
/// Motion: every bar follows its own mix of quick sines at unrelated
/// frequencies, and all of them swell together on a shared pulse of about
/// 114 beats a minute, so it reads as music rather than noise. Starting
/// and stopping playback eases the bars to and from a calm, frozen wave at
/// lower brightness. With Reduce Motion they stay frozen.
struct CardSideEqualizer: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When `isActive` last changed — the start of the ease in or out.
    @State private var changedAt = Date.distantPast
    /// Keeps the timeline running while the bars settle after a stop.
    @State private var isSettling = false

    /// The card's width plus the bars on either side, centred on the card.
    static let size = CGSize(width: NowPlayingCard.cardSize.width + 2 * sideWidth, height: 140)
    private static let barsPerSide = 9
    private static let barWidth: CGFloat = 3
    private static let spacing: CGFloat = 5.6
    /// From the card's edge to the first bar.
    private static let inset: CGFloat = 8
    private static let sideWidth = inset + spacing * CGFloat(barsPerSide)
    private static let blendDuration: TimeInterval = 0.8

    private static let color = Theme.mutedText

    private struct Bar {
        let x: CGFloat
        /// Tallest it gets while playing.
        let peak: CGFloat
        /// Its height in the calm, frozen wave.
        let rest: CGFloat
        let opacity: Double
        let waves: [(frequency: Double, phase: Double, weight: Double)]
    }

    private static let bars: [Bar] = {
        // Cheap, stable pseudo-random numbers in 0..<1.
        func random(_ seed: Double) -> Double {
            let value = sin(seed * 12.9898 + 78.233) * 43_758.5453
            return value - value.rounded(.down)
        }
        var bars: [Bar] = []
        let cardLeft = sideWidth
        let cardRight = sideWidth + NowPlayingCard.cardSize.width
        for side in 0..<2 {
            for index in 0..<barsPerSide {
                let seed = Double(side * 100 + index)
                // 0 next to the card, 1 at the outer edge.
                let distance = Double(index) / Double(barsPerSide - 1)
                let envelope = 0.28 + 0.72 * pow(1 - distance, 1.15)
                let peak = 140 * CGFloat(envelope * (0.72 + 0.28 * random(seed + 0.1)))
                let offset = inset + spacing * CGFloat(index)
                let x = side == 0 ? cardLeft - offset - barWidth : cardRight + offset
                bars.append(Bar(
                    x: x,
                    peak: peak,
                    rest: max(6, peak * CGFloat(0.22 + 0.18 * random(seed + 0.2))),
                    opacity: 1 - 0.72 * distance,
                    waves: [
                        (1.1 + random(seed + 0.3) * 0.9, random(seed + 0.4) * 6.28, 0.5),
                        (2.3 + random(seed + 0.5) * 1.3, random(seed + 0.6) * 6.28, 0.3),
                        (3.9 + random(seed + 0.7) * 1.8, random(seed + 0.8) * 6.28, 0.2),
                    ]
                ))
            }
        }
        return bars
    }()

    var body: some View {
        Group {
            if (isActive || isSettling) && !reduceMotion {
                TimelineView(.animation) { context in
                    wave(at: context.date)
                }
            } else {
                wave(at: nil)
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

    /// `date` nil draws the calm, frozen wave.
    private func wave(at date: Date?) -> some View {
        let blend = date.map { intensity(at: $0) } ?? 0
        let time = date?.timeIntervalSinceReferenceDate ?? 0
        // Paused, the wave dims a little.
        let brightness = 0.55 + 0.45 * blend
        return Canvas { context, size in
            let rects = Self.bars.map { bar -> (CGRect, Double) in
                let height = Self.height(of: bar, at: time, intensity: blend)
                return (CGRect(x: bar.x, y: (size.height - height) / 2, width: Self.barWidth, height: height),
                        bar.opacity * brightness)
            }
            for (rect, opacity) in rects {
                var bar = context
                bar.opacity = opacity
                bar.fill(Path(roundedRect: rect, cornerRadius: Self.barWidth / 2), with: .color(Self.color))
            }
        }
    }

    /// 0 at rest, 1 while playing, eased in between.
    private func intensity(at date: Date) -> Double {
        let progress = min(max(date.timeIntervalSince(changedAt) / Self.blendDuration, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        return isActive ? eased : 1 - eased
    }

    private static func height(of bar: Bar, at time: TimeInterval, intensity: Double) -> CGFloat {
        guard intensity > 0 else { return bar.rest }
        let signal = bar.waves.reduce(0.0) { sum, wave in
            sum + wave.weight * sin(2 * .pi * wave.frequency * time + wave.phase)
        }
        // A shared pulse, ~114 bpm, that swells every bar together.
        let pulse = 0.72 + 0.28 * pow(max(0, sin(2 * .pi * 1.9 * time)), 2)
        let level = min(max((signal + 1) / 2 * pulse, 0), 1)
        let floor = bar.peak * 0.16
        let moving = floor + (bar.peak - floor) * CGFloat(level)
        return bar.rest + (moving - bar.rest) * CGFloat(intensity)
    }
}
