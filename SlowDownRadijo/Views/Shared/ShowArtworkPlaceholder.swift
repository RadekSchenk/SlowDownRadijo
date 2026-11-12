import SwiftUI

/// Stands in for a show's photo when it has none — a special broadcast the
/// station put on the web without one, say — or while it's still loading:
/// the station's logo on a dark violet tile with a faint sunset glow.
struct ShowArtworkPlaceholder: View {
    var cornerRadius: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Theme.statsCardRaised
                RadialGradient(
                    colors: [Theme.sunOrange.opacity(0.35), Theme.liveRed.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.5, y: 0.85),
                    startRadius: 0,
                    endRadius: side * 0.9
                )
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.46)
                    .opacity(0.9)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}
