import SwiftUI

// The pieces of "Zimní vzhled" (WinterSeason, Figma "Advent ❄︎").

/// Turns the logo's sun into a Christmas bauble: a gold cap on top of the
/// striped "O" and a thread it hangs on. Laid over `BrandLogo` (the white
/// wordmark) of `size`; the thread reaches `threadLength` above the sun
/// and fades in towards its top end. `progress` 0…1 lets the thread run
/// down and the cap appear (the winter splash); 1 is the resting state.
struct WinterBauble: View {
    let size: CGSize
    var threadLength: CGFloat = 16
    var progress: CGFloat = 1

    /// The sun in `BrandLogo.png`, as in `AnimatedBrandLogo`.
    private static let sun = CGRect(x: 0.378, y: 0.069, width: 0.258, height: 0.315)

    var body: some View {
        let centerX = Self.sun.midX * size.width
        let sunTop = Self.sun.minY * size.height
        // Figma: a 7 × 3.6 cap on the header's 80pt-wide logo.
        let cap = CGSize(width: size.width * 0.0875, height: size.width * 0.045)
        let capTop = sunTop - cap.height * 0.7
        let thread = max(0.75, size.width * 0.005)
        let ring = size.width >= 120 ? size.width * 0.03 : 0

        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(width: thread, height: threadLength)
                .scaleEffect(x: 1, y: progress, anchor: .bottom)
                .offset(x: centerX - thread / 2, y: capTop - ring * 0.8 - threadLength)

            Group {
                if ring > 0 {
                    Circle()
                        .strokeBorder(Self.gold, lineWidth: ring * 0.28)
                        .frame(width: ring, height: ring)
                        .offset(x: centerX - ring / 2, y: capTop - ring * 0.85)
                }
                RoundedRectangle(cornerRadius: cap.height * 0.25, style: .continuous)
                    .fill(Self.gold)
                    .frame(width: cap.width, height: cap.height)
                    .offset(x: centerX - cap.width / 2, y: capTop)
            }
            .opacity(Double(max(0, progress * 2 - 1)))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static let gold = LinearGradient(
        colors: [Color(hex: 0xF5C75C), Color(hex: 0xFFE38C), Color(hex: 0xC7872A)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// Slowly falling snow: `count` small flakes that drift down and sway a
/// little, each on its own pace, wrapping round at the bottom. With
/// `fadesDown` they thin out towards the bottom edge (the home header:
/// they never reach the text). Reduce Motion stops them where they are;
/// Low Power Mode hides them.
struct Snowfall: View {
    var count: Int = 32
    var fadesDown: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        Group {
            if lowPower {
                Color.clear
            } else if reduceMotion {
                flakes(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    flakes(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func flakes(at time: TimeInterval) -> some View {
        Canvas { context, size in
            guard size.height > 0 else { return }
            let span = size.height + 12
            for index in 0..<count {
                let radius = 1.1 + 2.0 * Self.random(index, 1)
                let speed = 8 + 14 * Self.random(index, 2)   // points a second
                let start = Self.random(index, 3) * span
                var y = (start + time * speed).truncatingRemainder(dividingBy: span) - 6
                if y < -6 { y += span }
                let sway = (5 + 8 * Self.random(index, 4))
                    * sin(time / (3 + 4 * Self.random(index, 5)) + 6.28 * Self.random(index, 6))
                let x = Self.random(index, 7) * size.width + sway
                let fade = fadesDown ? max(0, 1 - y / size.height) : 1
                let opacity = (0.3 + 0.55 * Self.random(index, 8)) * fade
                guard opacity > 0.01 else { continue }
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Color(hex: 0xF6F4FF, alpha: opacity))
                )
            }
        }
    }

    /// A fixed pseudo-random number in 0..<1 for a flake and a property, so
    /// every flake keeps its own size, pace and path.
    private static func random(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return value - value.rounded(.down)
    }
}
