import SwiftUI

/// Flat, single-color play/pause button — a plain `liveRed` circle with no
/// gradient or glow, sized to sit inline in the now-playing row rather than
/// as a standalone hero control. `liveRed` (not `sunOrange`) since the
/// 2026-08-23 hero redesign introduced a dedicated "now playing" accent —
/// see `Theme.liveRed`.
struct PlayButton: View {
    let state: PlaybackState
    let action: () -> Void

    var diameter: CGFloat = 64
    var iconSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            AccentCircle(diameter: diameter) {
                switch state {
                case .connecting:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .transition(.iconSwap)
                case .playing:
                    Image(systemName: "pause.fill")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.iconSwap)
                default:
                    Image(systemName: "play.fill")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                        .transition(.iconSwap)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .connecting)
        // Library P5 — icon swap: from 25% scale through a 2px blur, 250ms.
        .animation(Motion.iconSwap, value: state)
    }
}
