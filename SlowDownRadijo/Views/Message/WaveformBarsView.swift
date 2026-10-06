import SwiftUI

/// Recording waveform spanning the full max duration: bars behind the
/// current position show real mic amplitude, bars ahead sit at a fixed
/// minimum — so it doubles as progress toward the time limit. Styled like
/// the home screen's `NowPlayingWaveform` (full width, bottom-aligned,
/// `liveRed` vs. `waveformMuted`).
struct WaveformBarsView: View {
    let levels: [Float]
    let activeCount: Int

    private let maxHeight: CGFloat = 40
    private let minHeight: CGFloat = 3

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(index < activeCount ? Theme.liveRed : Theme.waveformMuted)
                    .frame(height: barHeight(for: index))
            }
        }
        .frame(maxWidth: .infinity, minHeight: maxHeight, maxHeight: maxHeight, alignment: .bottom)
        .animation(.easeOut(duration: 0.15), value: levels)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < activeCount else { return minHeight }
        return max(minHeight, CGFloat(levels[index]) * maxHeight)
    }
}
