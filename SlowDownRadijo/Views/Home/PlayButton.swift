import SwiftUI

/// Flat, single-color play/pause button (per the "radio-flat-typo" Figma
/// redesign) — a plain `sunOrange` circle with no gradient or glow, sized
/// to sit inline in the now-playing row rather than as a standalone hero
/// control.
struct PlayButton: View {
    let state: PlaybackState
    let action: () -> Void

    var diameter: CGFloat = 64
    var iconSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.sunOrange)
                    .frame(width: diameter, height: diameter)

                switch state {
                case .connecting:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                case .playing:
                    Image(systemName: "pause.fill")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                default:
                    Image(systemName: "play.fill")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .connecting)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
    }
}
