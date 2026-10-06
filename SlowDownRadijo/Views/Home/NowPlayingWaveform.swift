import SwiftUI

/// Full-width, bottom-anchored equalizer shown under the play button and
/// show name. Not real audio analysis — tapping the live stream's audio
/// buffer for FFT was considered and deliberately skipped as too much
/// risk/complexity for a decorative element (see project notes). Instead it
/// behaves like an equalizer is expected to:
///
/// * a **beat** (100–130 bpm, a different tempo for every track) kicks the
///   bars up fast — a 60ms attack — and lets them fall back over ~220ms; each
///   bar reacts with its own weight and a few milliseconds of jitter, and the
///   four beats of a bar carry an accent pattern (strong, soft, medium, soft);
/// * between the beats every bar **flutters** on three quick, uneven sine
///   waves, so it never rests;
/// * when it appears (and on every new track) the bars **rise from the left,
///   one after another**, 8ms apart over 400ms on the library's smooth-out
///   curve (transitions.dev P13/P18 — staggered rise).
///
/// Everything is a pure function of time, so motion is continuous and nothing
/// needs per-frame state. Bars are square-cornered; the played part is
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

    private static let attack = 0.06
    private static let release = 0.22
    private static let riseDuration = 0.40
    private static let riseStagger = 0.008

    @State private var bars: [Bar] = NowPlayingWaveform.randomBars()
    @State private var rhythm = Rhythm.random()
    @State private var startedAt = Date.timeIntervalSinceReferenceDate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Wave {
        let frequency: Double
        let phase: Double
        let weight: Double
    }

    private struct Bar {
        let amplitude: Double
        let waves: [Wave]
        let beatWeight: Double
        let beatJitter: Double
    }

    private struct Rhythm {
        let period: Double
        let accents: [Double]

        static func random() -> Rhythm {
            Rhythm(
                period: .random(in: 0.46...0.60),
                accents: [1.0, 0.55, 0.8, 0.55]
            )
        }
    }

    private static func randomBars() -> [Bar] {
        (0..<barCount).map { _ in
            Bar(
                amplitude: .random(in: 0.6...1.0),
                waves: [
                    Wave(frequency: .random(in: 0.8...1.6), phase: .random(in: 0...(2 * .pi)), weight: 0.5),
                    Wave(frequency: .random(in: 1.6...2.6), phase: .random(in: 0...(2 * .pi)), weight: 0.3),
                    Wave(frequency: .random(in: 2.6...3.4), phase: .random(in: 0...(2 * .pi)), weight: 0.2),
                ],
                beatWeight: .random(in: 0.35...1.0),
                beatJitter: .random(in: -0.035...0.035)
            )
        }
    }

    private var elapsedBarCount: Int {
        Int((Double(Self.barCount) * progress).rounded())
    }

    var body: some View {
        Group {
            if reduceMotion {
                // A still frame, no beat and no rise.
                waveform(time: 0, riseDone: true)
            } else {
                TimelineView(.animation) { context in
                    waveform(time: context.date.timeIntervalSinceReferenceDate, riseDone: false)
                }
            }
        }
        .frame(height: Self.height)
        .onChange(of: trackID) { _, _ in
            // A new track: a different tempo and pattern, rising in afresh.
            bars = Self.randomBars()
            rhythm = Rhythm.random()
            startedAt = Date.timeIntervalSinceReferenceDate
        }
    }

    private func waveform(time: Double, riseDone: Bool) -> some View {
        let elapsedCount = elapsedBarCount
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(bars.indices, id: \.self) { index in
                let rise = riseDone ? 1 : Self.rise(forBar: index, at: time - startedAt)
                let level = Self.level(for: bars[index], rhythm: rhythm, at: time)
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

    /// 0…1 height of one bar at `time`: fast flutter plus the beat kick.
    private static func level(for bar: Bar, rhythm: Rhythm, at time: Double) -> Double {
        let flutterSum = bar.waves.reduce(0.0) { sum, wave in
            sum + sin(time * wave.frequency * 2 * .pi + wave.phase) * wave.weight
        }
        let flutter = 0.5 + 0.5 * flutterSum

        let shifted = time + bar.beatJitter
        let beatIndex = Int(floor(shifted / rhythm.period))
        let sinceBeat = shifted - Double(beatIndex) * rhythm.period
        let accent = rhythm.accents[((beatIndex % rhythm.accents.count) + rhythm.accents.count) % rhythm.accents.count]

        // Fast attack out of whatever is left of the previous beat, then a
        // slower exponential fall.
        let leftover = exp(-(rhythm.period - attack) / release)
        let envelope: Double
        if sinceBeat < attack {
            let ramp = sinceBeat / attack
            envelope = leftover + (1 - leftover) * (1 - pow(1 - ramp, 2))
        } else {
            envelope = exp(-(sinceBeat - attack) / release)
        }
        let beat = envelope * accent * bar.beatWeight

        let mixed = 0.35 * flutter + 0.65 * beat
        return min(1, 0.10 + 0.90 * bar.amplitude * mixed)
    }
}
