import SwiftUI

/// Concentric rings + soft color glows behind a center button — reused for
/// the idle/recording mic button and the success checkmark, matching the
/// Figma "visualizer-container" / "success-container" glow treatment
/// (recreated as blurred circles rather than imported blur PNGs/SVGs, same
/// technique as `SplashScreenView`).
struct RecordingVisualizerView<Content: View>: View {
    let primaryGlow: Color
    let secondaryGlow: Color
    let isPulsing: Bool
    var ringRadii: [Double] = [80, 105, 130]
    @ViewBuilder let content: () -> Content

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(secondaryGlow)
                .frame(width: 150, height: 150)
                .blur(radius: 50)
                .opacity(0.4)
                .offset(y: 10)

            Circle()
                .fill(primaryGlow)
                .frame(width: 130, height: 130)
                .blur(radius: 45)
                .opacity(0.35)

            ForEach(ringRadii, id: \.self) { radius in
                Circle()
                    .strokeBorder(primaryGlow.opacity(0.5), lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)
            }
            .scaleEffect(isPulsing && pulse ? 1.05 : 1)

            content()
        }
        .frame(height: 280)
        .onAppear {
            guard isPulsing else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
