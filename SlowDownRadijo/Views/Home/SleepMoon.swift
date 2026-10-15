import SwiftUI

/// The night sky in the sleep timer sheet's header: a glowing lavender
/// crescent that drifts gently and breathes its halo, with stars — four-
/// pointed sparkles and dots — twinkling around it, each on its own rhythm.
/// While a timer runs the halo is brighter. With Reduce Motion it all
/// holds still.
struct SleepMoon: View {
    /// A timer is running.
    var isOn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    static let size = CGSize(width: 108, height: 68)

    private static let moon = Color(hex: 0xD6CCFF)
    private static let halo = Color(hex: 0x9C8CFF)

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let sparkle: Bool
        let duration: Double
        let delay: Double
    }

    private static let stars: [Star] = [
        Star(x: 14, y: 16, size: 9, sparkle: true, duration: 2.2, delay: 0.0),
        Star(x: 30, y: 46, size: 3, sparkle: false, duration: 1.7, delay: 0.6),
        Star(x: 6, y: 38, size: 2.5, sparkle: false, duration: 2.6, delay: 1.1),
        Star(x: 40, y: 8, size: 2.5, sparkle: false, duration: 1.9, delay: 0.3),
        Star(x: 86, y: 10, size: 11, sparkle: true, duration: 2.8, delay: 0.9),
        Star(x: 98, y: 34, size: 3, sparkle: false, duration: 2.1, delay: 0.2),
        Star(x: 80, y: 54, size: 7, sparkle: true, duration: 2.4, delay: 1.4),
        Star(x: 102, y: 58, size: 2.5, sparkle: false, duration: 1.6, delay: 0.8),
        Star(x: 22, y: 60, size: 2, sparkle: false, duration: 2.9, delay: 1.7),
    ]

    var body: some View {
        ZStack {
            // Halo.
            Circle()
                .fill(RadialGradient(colors: [Self.halo.opacity(isOn ? 0.55 : 0.4), .clear],
                                     center: .center, startRadius: 4, endRadius: 34))
                .frame(width: 68, height: 68)
                .scaleEffect(animate ? 1.08 : 0.94)
                .opacity(animate ? 1 : 0.75)
                .position(x: Self.size.width / 2, y: Self.size.height / 2)

            ForEach(Self.stars.indices, id: \.self) { index in
                star(Self.stars[index])
            }

            Image(systemName: "moon.fill")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Self.moon)
                .rotationEffect(.degrees(-18))
                .shadow(color: Self.halo.opacity(0.9), radius: 8)
                .offset(y: animate ? -2 : 2)
                .position(x: Self.size.width / 2, y: Self.size.height / 2)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.easeInOut(duration: 0.4), value: isOn)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func star(_ star: Star) -> some View {
        Twinkle(duration: star.duration, delay: star.delay, still: reduceMotion) {
            if star.sparkle {
                Image(systemName: "sparkle")
                    .font(.system(size: star.size, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(Self.moon)
                    .frame(width: star.size, height: star.size)
            }
        }
        .position(x: star.x, y: star.y)
    }
}

/// Fades and shrinks its content in and out forever, on its own rhythm.
private struct Twinkle<Content: View>: View {
    let duration: Double
    let delay: Double
    let still: Bool
    @ViewBuilder let content: Content

    @State private var bright = false

    var body: some View {
        content
            .opacity(still ? 0.8 : (bright ? 1 : 0.2))
            .scaleEffect(still ? 1 : (bright ? 1 : 0.65))
            .onAppear {
                guard !still else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    bright = true
                }
            }
    }
}
