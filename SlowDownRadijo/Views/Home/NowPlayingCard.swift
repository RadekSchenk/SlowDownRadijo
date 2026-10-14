import SwiftUI
import UIKit

/// The home screen's "Programme preview" (Figma "variation-3-card", node
/// 12318:5168): the current show's artwork as a 230 × 230 card under a
/// dark scrim, flanked by `CardSideEqualizer`. The title and host sit
/// below it (`HomeView`). The card is centred; the equalizer keeps Figma's
/// exact offsets from it, so on wider phones the extra room stays empty
/// rather than stretching.
struct NowPlayingCard: View {
    let artwork: UIImage?
    let isPlaying: Bool
    /// Off for artwork with its own lettering (`Show.artworkHasText`).
    var showsScrim = true

    static let cardSize = CGSize(width: 230, height: 230)

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
        ZStack {
            artworkLayer

            // "gradient-scrim": clear until 45%, then into near-black.
            if showsScrim {
                LinearGradient(
                    stops: [
                        .init(color: Self.scrim.opacity(0), location: 0.45),
                        .init(color: Self.scrim.opacity(0.79), location: 0.80),
                        .init(color: Self.scrim.opacity(0.96), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
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

    /// `rgba(13, 13, 15, …)` in Figma.
    private static let scrim = Color(hex: 0x0D0D0F)
}

/// The bars either side of `NowPlayingCard` (Figma "Equalizer", node
/// 12318:5183), driven by the design's own keyframes: 16 steps of 250ms,
/// ease-in-out, looping every 4s. Each bar grows and shrinks around the
/// frame's vertical centre. Only the five bars on each side that Figma
/// shows are drawn — the ones behind the card are at 0% opacity there.
///
/// Animates only while playing; paused (or with Reduce Motion) it rests on
/// the design's first frame.
struct CardSideEqualizer: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Figma frame: 322 × 140, 14pt in from each side of the 350pt preview.
    static let size = CGSize(width: 322, height: 140)
    private static let period: TimeInterval = 4
    private static let barWidth: CGFloat = 3
    private static let color = Color(hex: 0x8C839C)

    private struct Bar {
        /// Left edge within the 322pt frame.
        let x: CGFloat
        let opacity: Double
        /// Heights at 0%, 6.25%, … 100% of the 4s loop (17 keyframes).
        let heights: [CGFloat]
    }

    private static let bars: [Bar] = [
        Bar(x: 0, opacity: 0.30, heights: [48.0, 43.37, 17.3, 51.12, 43.04, 17.38, 51.37, 42.71, 17.46, 51.62, 42.38, 17.55, 51.86, 42.05, 17.65, 52.1, 48.0]),
        Bar(x: 10.67, opacity: 0.30, heights: [94.0, 109.06, 69.14, 40.38, 109.34, 68.47, 40.78, 109.61, 67.81, 41.19, 109.86, 67.14, 41.6, 110.11, 66.48, 42.02, 94.0]),
        Bar(x: 21.33, opacity: 0.50, heights: [62.0, 33.93, 74.38, 35.58, 34.31, 74.39, 35.19, 34.69, 74.4, 34.81, 35.07, 74.4, 34.43, 35.46, 74.39, 34.05, 62.0]),
        Bar(x: 32, opacity: 0.50, heights: [110.0, 49.33, 77.55, 128.94, 48.84, 78.33, 128.66, 48.35, 79.1, 128.36, 47.87, 79.88, 128.05, 47.4, 80.67, 127.72, 110.0]),
        Bar(x: 42.67, opacity: 0.72, heights: [82.0, 89.12, 30.2, 71.65, 88.72, 30.04, 72.22, 88.31, 29.88, 72.78, 87.9, 29.73, 73.35, 87.47, 29.6, 73.91, 82.0]),
        Bar(x: 277.33, opacity: 0.72, heights: [104.0, 102.75, 36.4, 103.08, 102.1, 36.41, 103.72, 101.45, 36.43, 104.35, 100.79, 36.47, 104.97, 100.12, 36.51, 105.59, 104.0]),
        Bar(x: 288, opacity: 0.50, heights: [82.0, 91.21, 67.89, 31.51, 91.56, 67.31, 31.75, 91.91, 66.72, 31.99, 92.24, 66.14, 32.24, 92.57, 65.55, 32.51, 82.0]),
        Bar(x: 298.67, opacity: 0.50, heights: [112.0, 53.22, 132.87, 73.86, 53.79, 133.07, 73.1, 54.37, 133.25, 72.33, 54.96, 133.42, 71.57, 55.56, 133.57, 70.81, 112.0]),
        Bar(x: 309.33, opacity: 0.30, heights: [90.0, 46.35, 55.45, 107.59, 45.84, 56.05, 107.49, 45.34, 56.65, 107.38, 44.85, 57.26, 107.26, 44.37, 57.87, 107.13, 90.0]),
        Bar(x: 320, opacity: 0.30, heights: [64.0, 73.08, 25.89, 50.06, 72.84, 25.67, 50.52, 72.6, 25.46, 50.97, 72.36, 25.25, 51.43, 72.1, 25.05, 51.88, 64.0]),
    ]

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    bars(at: time.truncatingRemainder(dividingBy: Self.period) / Self.period)
                }
            } else {
                bars(at: 0)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// `phase` 0…1 through the loop.
    private func bars(at phase: Double) -> some View {
        Canvas { context, size in
            for bar in Self.bars {
                let height = Self.height(of: bar, at: phase)
                let rect = CGRect(x: bar.x, y: (size.height - height) / 2, width: Self.barWidth, height: height)
                var barContext = context
                barContext.opacity = bar.opacity
                barContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.color))
            }
        }
    }

    private static func height(of bar: Bar, at phase: Double) -> CGFloat {
        let segments = bar.heights.count - 1
        let position = phase * Double(segments)
        let index = min(Int(position), segments - 1)
        let local = easeInOut(position - Double(index))
        let from = bar.heights[index]
        let to = bar.heights[index + 1]
        return from + (to - from) * CGFloat(local)
    }

    /// CSS `ease-in-out`, cubic-bezier(0.42, 0, 0.58, 1): solve x(t) = `x`
    /// for t, return y(t).
    private static func easeInOut(_ x: Double) -> Double {
        let (x1, y1, x2, y2) = (0.42, 0.0, 0.58, 1.0)
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low = 0.0, high = 1.0, t = x
        for _ in 0..<20 {
            let value = bezier(t, x1, x2)
            if abs(value - x) < 0.0005 { break }
            if value < x { low = t } else { high = t }
            t = (low + high) / 2
        }
        return bezier(t, y1, y2)
    }
}
