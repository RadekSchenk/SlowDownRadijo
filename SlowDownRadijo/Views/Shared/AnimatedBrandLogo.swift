import SwiftUI

/// The white Slow Down Rádijo wordmark whose sun — the striped "O" —
/// catches a band of warm light now and then: shortly after it appears,
/// then once a minute, the light sweeps across the stripes left to right.
/// Only the sun's stripes light up (the band is masked by the logo's own
/// shape and kept within the sun). With Reduce Motion it stays still.
struct AnimatedBrandLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = the band waits left of the sun, 1 = it has passed out right.
    @State private var sweep: CGFloat = 0

    /// Where the sun sits in `BrandLogo.png` (1225 × 1015), as fractions.
    private static let sun = CGRect(x: 0.378, y: 0.069, width: 0.258, height: 0.315)
    private static let firstDelay: Duration = .seconds(2)
    private static let interval: Duration = .seconds(60)
    private static let duration: Double = 1.6

    var body: some View {
        logo
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
