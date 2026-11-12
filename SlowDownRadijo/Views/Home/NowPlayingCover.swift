import SwiftUI
import UIKit

/// The show's cover in the home screen's compact player (Figma
/// "Cover s ekvalizérem", node 12390:271): the show photo, 96 × 96 with
/// 10pt corners, flanked by `CardSideEqualizer` in a 140 × 108 box. The
/// title and host sit to its right, the song and player controls below
/// (`HomeView`).
struct NowPlayingCover: View {
    let artwork: UIImage?
    let isPlaying: Bool

    static let artworkSize: CGFloat = 96
    static let size = CGSize(width: 140, height: 108)

    var body: some View {
        artworkLayer
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
            .frame(width: Self.size.width, height: Self.size.height)
            .background {
                CardSideEqualizer(isActive: isPlaying, style: .compact)
            }
    }

    @ViewBuilder
    private var artworkLayer: some View {
        if let artwork {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .clipped()
                .transition(.opacity)
        } else {
            // Artwork still loading, or the show has none (a special
            // broadcast from the web).
            ShowArtworkPlaceholder(cornerRadius: 0)
        }
    }
}

/// The beat the home screen's motion shares: the bars either side of the
/// cover and the coloured clouds behind the header swell on it together,
/// about 114 times a minute. 0 between beats, 1 on one.
enum RadioPulse {
    static let beatsPerSecond = 1.9

    static func beat(at time: TimeInterval) -> Double {
        pow(max(0, sin(2 * .pi * beatsPerSecond * time)), 2)
    }
}

/// The waveform either side of the show's cover: thin bars growing up and
/// down from the cover's middle line — a sound wave spreading out from the
/// show. `Style.compact` is the home screen's (Figma node 12390:273…282:
/// five 2pt bars a side in `#8C839C` at half opacity); `Style.large` the
/// earlier 230pt card's, nine a side, fading towards the page's edges.
///
/// Motion: every bar follows its own mix of quick sines at unrelated
/// frequencies, and all of them swell together on a shared pulse of about
/// 114 beats a minute (`RadioPulse`), so it reads as music rather than
/// noise. Starting
/// and stopping playback eases the bars to and from a calm, frozen wave at
/// lower brightness. With Reduce Motion they stay frozen.
struct CardSideEqualizer: View {
    let isActive: Bool
    var style: Style = .compact

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When `isActive` last changed — the start of the ease in or out.
    @State private var changedAt = Date.distantPast
    /// Keeps the timeline running while the bars settle after a stop.
    @State private var isSettling = false

    private static let blendDuration: TimeInterval = 0.8

    struct Style {
        let coverWidth: CGFloat
        let barsPerSide: Int
        let barWidth: CGFloat
        let spacing: CGFloat
        /// From the cover's edge to the first bar.
        let inset: CGFloat
        let height: CGFloat
        /// The tallest bar's peak.
        let maxPeak: CGFloat
        let color: Color
        /// Next to the cover…
        let opacity: Double
        /// …and how much of it the outermost bar loses.
        let falloff: Double

        var sideWidth: CGFloat { inset + spacing * CGFloat(barsPerSide) }
        var size: CGSize { CGSize(width: coverWidth + 2 * sideWidth, height: height) }

        static let compact = Style(
            coverWidth: NowPlayingCover.artworkSize, barsPerSide: 5, barWidth: 2, spacing: 4.57, inset: 1.7,
            height: NowPlayingCover.size.height, maxPeak: 60, color: Color(hex: 0x8C839C),
            opacity: 0.5, falloff: 0.3, id: 0
        )
        static let large = Style(
            coverWidth: 230, barsPerSide: 9, barWidth: 3, spacing: 5.6, inset: 8,
            height: 140, maxPeak: 140, color: Theme.mutedText,
            opacity: 1, falloff: 0.72, id: 1
        )

        fileprivate let id: Int
    }

    private struct Bar {
        let x: CGFloat
        /// Tallest it gets while playing.
        let peak: CGFloat
        /// Its height in the calm, frozen wave.
        let rest: CGFloat
        let opacity: Double
        let waves: [(frequency: Double, phase: Double, weight: Double)]
    }

    private static let compactBars = makeBars(.compact)
    private static let largeBars = makeBars(.large)
    private var bars: [Bar] { style.id == 0 ? Self.compactBars : Self.largeBars }

    private static func makeBars(_ style: Style) -> [Bar] {
        // Cheap, stable pseudo-random numbers in 0..<1.
        func random(_ seed: Double) -> Double {
            let value = sin(seed * 12.9898 + 78.233) * 43_758.5453
            return value - value.rounded(.down)
        }
        var bars: [Bar] = []
        let coverLeft = style.sideWidth
        let coverRight = style.sideWidth + style.coverWidth
        for side in 0..<2 {
            for index in 0..<style.barsPerSide {
                let seed = Double(side * 100 + index)
                // 0 next to the cover, 1 at the outer edge.
                let distance = Double(index) / Double(max(style.barsPerSide - 1, 1))
                let envelope = 0.28 + 0.72 * pow(1 - distance, 1.15)
                let peak = style.maxPeak * CGFloat(envelope * (0.72 + 0.28 * random(seed + 0.1)))
                let offset = style.inset + style.spacing * CGFloat(index)
                let x = side == 0 ? coverLeft - offset - style.barWidth : coverRight + offset
                bars.append(Bar(
                    x: x,
                    peak: peak,
                    rest: max(style.barWidth * 2, peak * CGFloat(0.22 + 0.18 * random(seed + 0.2))),
                    opacity: style.opacity * (1 - style.falloff * distance),
                    waves: [
                        (1.1 + random(seed + 0.3) * 0.9, random(seed + 0.4) * 6.28, 0.5),
                        (2.3 + random(seed + 0.5) * 1.3, random(seed + 0.6) * 6.28, 0.3),
                        (3.9 + random(seed + 0.7) * 1.8, random(seed + 0.8) * 6.28, 0.2),
                    ]
                ))
            }
        }
        return bars
    }

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
        .frame(width: style.size.width, height: style.size.height)
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
        let bars = self.bars
        let barWidth = style.barWidth
        let color = style.color
        return Canvas { context, size in
            let rects = bars.map { bar -> (CGRect, Double) in
                let height = Self.height(of: bar, at: time, intensity: blend)
                return (CGRect(x: bar.x, y: (size.height - height) / 2, width: barWidth, height: height),
                        bar.opacity * brightness)
            }
            for (rect, opacity) in rects {
                var bar = context
                bar.opacity = opacity
                bar.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
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
        // The shared pulse that swells every bar (and the clouds behind
        // the header) together.
        let pulse = 0.72 + 0.28 * RadioPulse.beat(at: time)
        let level = min(max((signal + 1) / 2 * pulse, 0), 1)
        let floor = bar.peak * 0.16
        let moving = floor + (bar.peak - floor) * CGFloat(level)
        return bar.rest + (moving - bar.rest) * CGFloat(intensity)
    }
}
