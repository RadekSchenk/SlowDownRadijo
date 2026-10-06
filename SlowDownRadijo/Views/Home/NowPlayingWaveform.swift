import SwiftUI

/// Full-width, bottom-anchored equalizer shown under the play button and
/// show name. Not real audio analysis — tapping the live stream's audio
/// buffer for FFT was considered and deliberately skipped as too much
/// risk/complexity for a decorative element (see project notes). It is
/// meant to look orderly rather than random:
///
/// * neighbouring bars are always similar — the shape is two smooth **hills**
///   that drift slowly across the row, one to the right (every 3.6s) and a
///   finer one to the left (every 2.4s);
/// * the whole row **swells together** about once a second (a soft pulse, not
///   a per-bar kick), so there is a visible rhythm without any jumping;
/// * the row is a little lower at both ends, which keeps it tidy;
/// * when it appears (and on every new track) the bars **rise from the left,
///   one after another**, 8ms apart over 400ms on the library's smooth-out
///   curve (transitions.dev P13/P18 — staggered rise).
///
/// Each track gets its own phase of the hills and its own pulse speed
/// (0.9–1.1s), so a new song looks a little different — but never chaotic.
/// Everything is a pure function of time, so the motion is continuous and
/// needs no per-frame state. Bars are square-cornered; the played part is
/// `liveRed`, the rest `#b8afdc`.
///
/// Only ever shown while actively playing — the caller (`ShowProgressBar`)
/// wraps this in `if isPlaying`, so the view itself doesn't track an
/// active/inactive state; when paused it's removed from the layout entirely
/// rather than dimmed, per the 2026-08-23 hero redesign.
struct NowPlayingWaveform: View {
    /// Fraction (0...1) of the current show elapsed — bars up to this
    /// fraction get the flat `liveRed` fill ("played"); the rest the
    /// brighter unplayed fill, matching the progress bar directly below.
    let progress: Double
    /// Any value that changes when the track changes — only used to
    /// trigger a reseed, never read for its content.
    let trackID: AnyHashable

    private static let barCount = 48
    private static let height: CGFloat = 40
    private static let minimumBarHeight: CGFloat = 3

    private static let riseDuration = 0.40
    private static let riseStagger = 0.008

    @State private var pattern = Pattern.random()
    @State private var startedAt = Date.timeIntervalSinceReferenceDate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What differs from track to track.
    private struct Pattern {
        let phaseA: Double
        let phaseB: Double
        let swellPeriod: Double

        static func random() -> Pattern {
            Pattern(
                phaseA: .random(in: 0...1),
                phaseB: .random(in: 0...1),
                swellPeriod: .random(in: 0.9...1.1)
            )
        }
    }

    private var elapsedBarCount: Int {
        Int((Double(Self.barCount) * progress).rounded())
    }

    var body: some View {
        Group {
            if reduceMotion {
                // A still frame, no drift, pulse or rise.
                waveform(time: 0, riseDone: true)
            } else {
                TimelineView(.animation) { context in
                    waveform(time: context.date.timeIntervalSinceReferenceDate, riseDone: false)
                }
            }
        }
        .frame(height: Self.height)
        .onChange(of: trackID) { _, _ in
            // A new track: another phase and pulse speed, rising in afresh.
            pattern = Pattern.random()
            startedAt = Date.timeIntervalSinceReferenceDate
        }
    }

    private func waveform(time: Double, riseDone: Bool) -> some View {
        let elapsedCount = elapsedBarCount
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                let rise = riseDone ? 1 : Self.rise(forBar: index, at: time - startedAt)
                let level = Self.level(forBar: index, pattern: pattern, at: time)
                Rectangle()
                    .fill(index < elapsedCount ? Theme.liveRed : Theme.equalizerUnplayed)
                    .frame(height: max(Self.minimumBarHeight, Self.height * level * rise))
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    /// 0…1, how far a bar has risen: staggered left to right, smooth-out.
    private static func rise(forBar index: Int, at elapsed: Double) -> Double {
        let progress = (elapsed - Double(index) * riseStagger) / riseDuration
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    /// 0…1 height of one bar: two drifting hills plus the shared swell, a
    /// little lower toward both ends.
    private static func level(forBar index: Int, pattern: Pattern, at time: Double) -> Double {
        let x = Double(index) / Double(barCount - 1)
        let hillA = 0.5 + 0.5 * sin(2 * .pi * (1.6 * x - time / 3.6 + pattern.phaseA))
        let hillB = 0.5 + 0.5 * sin(2 * .pi * (3.1 * x + time / 2.4 + pattern.phaseB))
        let pulse = 0.5 + 0.5 * cos(2 * .pi * time / pattern.swellPeriod)
        let swell = pulse * pulse
        let mixed = 0.45 * hillA + 0.30 * hillB + 0.25 * swell
        let taper = 0.78 + 0.22 * sin(.pi * x)
        return min(1, (0.12 + 0.88 * mixed) * taper)
    }
}
