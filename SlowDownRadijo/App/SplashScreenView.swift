import SwiftUI

/// Matches the Figma splash-screen redesign (node 32:25): brand purple
/// background, a soft ambient glow behind the logo, the logo mark, a
/// tagline, and a copyright footer.
///
/// The glow is recreated as a blurred `Circle` rather than importing the
/// Figma SVG — it's just a single blurred circle (`fill #E8652B`, 35%
/// opacity, Gaussian blur σ45), which SwiftUI expresses natively and
/// resolution-independently.
///
/// Typography deviates from the rest of the app on purpose: Figma specified
/// Outfit/Inter, the user asked for Manrope instead of either — see
/// `Theme.Typography.Manrope`. Every other screen uses system SF Pro.
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Theme.brandPurple

            Circle()
                .fill(Color(hex: 0xE8652B))
                .frame(width: 300, height: 300)
                .blur(radius: 45)
                .opacity(0.35)
                .offset(y: -30)

            VStack {
                Spacer().frame(height: 20)

                VStack(spacing: 24) {
                    Image("BrandLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 301)

                    Text(L10n.tagline)
                        .font(Theme.Typography.Manrope.medium(size: 16, relativeTo: .subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Text("SLOW DOWN RÁDIJO © 2026")
                    .font(Theme.Typography.Manrope.regular(size: 11, relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.top, 80)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashScreenView()
}
