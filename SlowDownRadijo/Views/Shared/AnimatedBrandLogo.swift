import SwiftUI

/// The white Slow Down Rádijo wordmark whose sun — the striped "O" — is
/// always gently alive: its stripes breathe like a slow equalizer, each on
/// its own rhythm, shortening by up to a tenth about the sun's middle and
/// back. Shortly after it appears, then once a minute, a band of warm
/// light also sweeps across the stripes left to right (masked by the
/// logo's own shape, kept within the sun). With Reduce Motion it stays
/// still.
struct AnimatedBrandLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = the band waits left of the sun, 1 = it has passed out right.
    @State private var sweep: CGFloat = 0

    /// Where the sun sits in `BrandLogo.png` (1225 × 1015), as fractions.
    private static let sun = CGRect(x: 0.378, y: 0.069, width: 0.258, height: 0.315)
    private static let firstDelay: Duration = .seconds(2)
    private static let interval: Duration = .seconds(60)
    private static let duration: Double = 1.6

    /// Each stripe's slice of the sun, as fractions of the logo's width
    /// (boundaries in the gaps between the stripes; the "L" ends at 455 px
    /// and the "W" starts at 798, so neither is touched).
    private static let stripes: [ClosedRange<CGFloat>] = {
        let edges: [CGFloat] = [458, 480, 503, 538, 581, 645, 697, 742, 765, 792]
        return zip(edges, edges.dropFirst()).map { ($0 / 1225)...($1 / 1225) }
    }()

    var body: some View {
        Group {
            if reduceMotion {
                logo
            } else {
                TimelineView(.animation) { context in
                    breathingLogo(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
            .overlay {
                GeometryReader { geometry in
                    let size = geometry.size
                    let sun = CGRect(
                        x: Self.sun.minX * size.width,
                        y: Self.sun.minY * size.height,
                        width: Self.sun.width * size.width,
                        height: Self.sun.height * size.height
                    )
                    let band = sun.width * 0.7
                    light
                        .frame(width: band, height: sun.height)
                        .offset(x: -band + sweep * (sun.width + band))
                        .frame(width: sun.width, height: sun.height, alignment: .leading)
                        .clipped()
                        .offset(x: sun.minX, y: sun.minY)
                }
                .mask(logo)
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
            .task {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: Self.firstDelay)
                while !Task.isCancelled {
                    sweep = 0
                    withAnimation(.easeInOut(duration: Self.duration)) { sweep = 1 }
                    try? await Task.sleep(for: Self.interval)
                }
            }
    }

    /// The logo without its sun, plus each stripe drawn on its own,
    /// shortened about the sun's middle by its own slow rhythm.
    private func breathingLogo(at time: TimeInterval) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let sun = CGRect(
                x: Self.sun.minX * size.width, y: Self.sun.minY * size.height,
                width: Self.sun.width * size.width, height: Self.sun.height * size.height
            )
            let anchor = UnitPoint(x: 0.5, y: sun.midY / max(size.height, 1))
            let stripesSpan = Self.stripes[0].lowerBound...Self.stripes[Self.stripes.count - 1].upperBound
            ZStack(alignment: .topLeading) {
                logo.mask {
                    // Everything but the stripes.
                    Rectangle()
                        .overlay(alignment: .topLeading) {
                            Rectangle()
                                .frame(width: (stripesSpan.upperBound - stripesSpan.lowerBound) * size.width, height: sun.height)
                                .offset(x: stripesSpan.lowerBound * size.width, y: sun.minY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                ForEach(Self.stripes.indices, id: \.self) { index in
                    let slice = Self.stripes[index]
                    logo
                        .scaleEffect(x: 1, y: Self.stripeScale(index, at: time), anchor: anchor)
                        .mask(alignment: .topLeading) {
                            Rectangle()
                                .frame(width: (slice.upperBound - slice.lowerBound) * size.width, height: sun.height)
                                .offset(x: slice.lowerBound * size.width, y: sun.minY)
                        }
                }
            }
        }
    }

    /// 0.9…1: two slow sines per stripe at unrelated speeds (0.2–0.5 Hz),
    /// so the sun never visibly repeats.
    private static func stripeScale(_ index: Int, at time: TimeInterval) -> CGFloat {
        let i = Double(index)
        let a = sin(2 * .pi * (0.21 + 0.031 * i) * time + i * 1.7)
        let b = sin(2 * .pi * (0.37 + 0.023 * (8 - i)) * time + i * 0.9)
        let level = (0.6 * a + 0.4 * b + 1) / 2
        return 0.9 + 0.1 * CGFloat(level)
    }

    private var logo: some View {
        // `BrandLogo` is the white wordmark (the app is dark-only).
        Image("BrandLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    /// Soft-edged: sunlight yellow at the rims, near-white in the middle.
    private var light: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(hex: 0xFFD66B, alpha: 0.85), location: 0.3),
                .init(color: Color(hex: 0xFFF6DC, alpha: 0.95), location: 0.5),
                .init(color: Color(hex: 0xFFD66B, alpha: 0.85), location: 0.7),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
