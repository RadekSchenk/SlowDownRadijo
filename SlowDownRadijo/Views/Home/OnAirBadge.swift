import SwiftUI

/// Red "ON-AIR" pill with a continuously pulsing dot — always animates
/// while visible, independent of whether local playback is actually
/// running (it reflects the schedule, not our player state).
struct OnAirBadge: View {
    private static let red = Color(hex: 0xD91F1F)

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Self.red)
                .frame(width: 10, height: 10)
                // Reduce Motion: a steady, fully lit dot instead of the pulse.
                .opacity(pulse || reduceMotion ? 1 : 0.35)

            Text(L10n.onAir)
                .font(Theme.Typography.Manrope.extraBold(size: 14))
                .foregroundStyle(Self.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Self.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
