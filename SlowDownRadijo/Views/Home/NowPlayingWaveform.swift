import SwiftUI

/// Full-width, bottom-anchored bar visualization shown under the play
/// button and show name. Not real audio analysis — tapping the live
/// stream's audio buffer for FFT was considered and deliberately skipped
/// as too much risk/complexity for a decorative element (see project
/// notes). Instead each bar drifts via two overlapping sine waves at
/// per-bar random, incommensurate frequencies, so the shape keeps changing
/// smoothly and never visibly loops within a song's length. Reseeds
/// (fresh random frequencies/phases) whenever `trackID` changes, so a new
/// track gets a visibly different pattern rather than the same drift
/// carrying over.
///
/// Only ever shown while actively playing — the caller (`HomeView`) wraps
/// this in `if playbackState == .playing`, so the view itself doesn't
/// track an active/inactive state; when paused it's removed from the
/// layout entirely rather than dimmed, per the 2026-08-23 hero redesign.
struct NowPlayingWaveform: View {
    /// Fraction (0...1) of the current show elapsed — bars up to this
    /// fraction get the warm yellow-to-`liveRed` gradient ("played"); the
    /// rest get a flat muted fill ("not yet played"), matching the
    /// progress bar directly below.
    let progress: Double
    /// Any value that changes when the track changes — only used to
    /// trigger a reseed, never read for its content.
    let trackID: AnyHashable

    private static let barCount = 48
    private static let height: CGFloat = 40

    @State private var bars: [BarMotion] = NowPlayingWaveform.randomBars()

    private struct BarMotion {
        let phase1: Double
        let phase2: Double
        let freq1: Double
        let freq2: Double
        let amplitude: Double
    }

    private static func randomBars() -> [BarMotion] {
        (0..<barCount).map { _ in
            BarMotion(
                phase1: .random(in: 0...(2 * .pi)),
                phase2: .random(in: 0...(2 * .pi)),
                freq1: .random(in: 0.15...0.35),
                freq2: .random(in: 0.05...0.12),
                amplitude: .random(in: 0.55...1.0)
            )
        }
    }

    private var elapsedBarCount: Int {
        Int((Double(Self.barCount) * progress).rounded())
    }

    var body: some View {
        TimelineView(.animation) { context in
            waveform(time: context.date.timeIntervalSinceReferenceDate)
        }
        .frame(height: Self.height)
        .onChange(of: trackID) { _, _ in
            bars = Self.randomBars()
        }
    }

    private func waveform(time: Double) -> some View {
        let elapsedCount = elapsedBarCount
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(bars.indices, id: \.self) { index in
                let bar = bars[index]
                let heightFraction = Self.heightFraction(for: bar, at: time)
                Capsule()
                    .fill(index < elapsedCount ? AnyShapeStyle(Theme.liveWaveformGradient) : AnyShapeStyle(Theme.waveformMuted))
                    .frame(height: max(3, Self.height * heightFraction))
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private static func heightFraction(for bar: BarMotion, at time: Double) -> Double {
        let wave = sin(time * bar.freq1 * 2 * .pi + bar.phase1) * 0.6
            + sin(time * bar.freq2 * 2 * .pi + bar.phase2) * 0.4
        let normalized = 0.5 + 0.5 * wave
        return 0.08 + normalized * bar.amplitude * 0.92
    }
}
