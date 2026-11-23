import SwiftUI

/// A pixel-for-pixel copy of the system launch screen (`UILaunchScreen` in
/// `project.yml`: the `LaunchBackground` colour with `LaunchLogo` centred
/// at its own size), laid over the app for a moment after launch and then
/// faded out (see `AppRootView`). Being identical to what iOS shows while
/// the app loads, the handover can't be seen: the listener gets one launch
/// screen that dissolves into the app, not two different ones in a row.
///
/// `winter` (the first launch of a day in the winter season, Figma
/// "Advent ❄︎" S3): starting from that same picture, the sky darkens to
/// night, snow starts to fall and the logo's sun is let down on a thread
/// as a bauble; on 24–26 December a short wish appears at the bottom.
/// The wordmark itself never moves, so it still reads as one screen.
struct SplashScreenView: View {
    var winter = false
    var christmas = false

    @State private var progress: CGFloat = 0

    /// Where the white wordmark sits inside `LaunchLogo` (240 × 222, the
    /// wordmark on a purple slab): 155.3 wide, centred. `BrandLogo` drawn
    /// at that width covers it exactly, without the slab.
    private static let wordmarkWidth: CGFloat = 155.33
    private static let wordmark = CGSize(width: wordmarkWidth, height: wordmarkWidth * 1015 / 1225)

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            // No resizing: iOS draws the launch image at its point size,
            // centred on the whole screen.
            Image("LaunchLogo")

            if winter {
                Group {
                    LinearGradient(
                        colors: [Color(hex: 0x1F1749), Color(hex: 0x433785)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Snowfall(count: 46, fadesDown: false)
                    Image("BrandLogo")
                        .resizable()
                        .frame(width: Self.wordmark.width, height: Self.wordmark.height)
                }
                .opacity(Double(min(1, progress * 1.6)))

                WinterBauble(size: Self.wordmark, threadLength: 1000, progress: progress)

                if christmas {
                    VStack {
                        Spacer()
                        Text(L10n.winterChristmasWish)
                            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 72)
                    }
                    .opacity(Double(max(0, progress * 2 - 1)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            guard winter else { return }
            withAnimation(.easeOut(duration: Self.reveal)) { progress = 1 }
        }
    }

    /// How long the winter picture takes to come in.
    static let reveal: Double = 0.7
}

#Preview {
    SplashScreenView()
}

#Preview("Zima") {
    SplashScreenView(winter: true, christmas: true)
}
