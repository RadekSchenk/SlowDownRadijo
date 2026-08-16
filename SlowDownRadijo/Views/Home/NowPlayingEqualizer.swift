import SwiftUI

/// Tiny 3-bar equalizer next to the "PRÁVĚ HRAJE" label. Only appears and
/// animates while audio is actually playing (`isActive`) — unlike
/// `OnAirBadge`, this reflects our own player state, not the schedule.
struct NowPlayingEqualizer: View {
    let isActive: Bool

    @State private var animate = false

    private struct Bar {
        let minHeight: CGFloat
        let maxHeight: CGFloat
        let duration: Double
        let delay: Double
    }

    private let bars: [Bar] = [
        Bar(minHeight: 3, maxHeight: 8, duration: 0.5, delay: 0.0),
        Bar(minHeight: 3, maxHeight: 12, duration: 0.4, delay: 0.1),
        Bar(minHeight: 3, maxHeight: 5, duration: 0.45, delay: 0.2)
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.sunOrange)
                    .frame(width: 3, height: animate ? bars[index].maxHeight : bars[index].minHeight)
                    .animation(
                        .easeInOut(duration: bars[index].duration)
                            .repeatForever(autoreverses: true)
                            .delay(bars[index].delay),
                        value: animate
                    )
            }
        }
        .frame(width: 14, height: 12, alignment: .bottom)
        .opacity(isActive ? 1 : 0)
        .onAppear { animate = isActive }
        .onChange(of: isActive) { _, newValue in
            animate = newValue
        }
    }
}
