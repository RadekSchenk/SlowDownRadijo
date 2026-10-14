import SwiftUI

/// The app's primary-action shape: a flat `Theme.liveRed` circle with the
/// Figma play-button drop shadow. Shared by `PlayButton` and the Vzkaz tab
/// so the two can't drift apart.
struct AccentCircle<Content: View>: View {
    var diameter: CGFloat = 54
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.liveRed)
                .frame(width: diameter, height: diameter)
                // CSS `0px 6px 8px rgba(0,0,0,0.2)` — blur roughly halves as a SwiftUI radius.
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 6)
            content()
        }
    }
}
