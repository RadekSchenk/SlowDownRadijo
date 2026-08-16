import SwiftUI

/// Live recording waveform: a fixed set of bars spanning the full 3-minute
/// max duration. Bars behind the current recording position are filled
/// (real amplitude, sampled from the mic) in orange; bars ahead sit dimmed
/// at a small fixed height — so the bar chart doubles as a progress
/// indicator toward the time limit, matching the Figma reference.
struct WaveformBarsView: View {
    let levels: [Float]
    let activeCount: Int

    private let maxHeight: CGFloat = 40
    private let minHeight: CGFloat = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(index < activeCount ? Theme.sunOrange : Theme.lavender.opacity(0.4))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.15), value: levels)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < activeCount else { return minHeight }
        let level = CGFloat(levels[index])
        return max(minHeight, level * maxHeight)
    }
}
