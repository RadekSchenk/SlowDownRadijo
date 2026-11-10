import SwiftUI

/// The coloured clouds behind the home screen's header (Figma "Hrající
/// mrak — rádio", node 12392:245): five soft, heavily blurred blobs in the
/// station's reds and violets behind the logo and the show.
///
/// While the radio plays they float through the space like smoke: each
/// wanders on its own slow, never-closing path, turns, stretches, and
/// changes shape (three overlapping lobes sliding against each other under
/// the blur), so the picture never visibly repeats. A companion to the
/// equalizer by the cover rather than a show of their own, they also swell
/// a little on the same beat as its bars (`RadioPulse`). Pressing pause slows them to a stop where they are
/// (no jump back) and dims them a touch; play eases them back in. With
/// Reduce Motion they stay still.
struct HeaderClouds: View {
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = DriftClock()
    /// Keeps the timeline running while the clouds slow down after a stop.
    @State private var isSettling = false

    /// Figma's frame: 390 wide, its top 30pt above the screen's.
    static let designWidth: CGFloat = 390
    static let top: CGFloat = -30
    /// Extra room above and below the frame, so the blur fades out on its
    /// own instead of being cut off — above, for pulling the page down.
    private static let marginAbove: CGFloat = 160
    private static let height: CGFloat = 520

    private struct Blob {
        /// Figma's ellipse frame, in the 390pt-wide design.
        let frame: CGRect
        let color: Color
        let opacity: Double
        /// Figma's layer blur (the SVG's standard deviation).
        let blur: CGFloat
        /// Drift periods in seconds, and phases.
        let periods: (x: Double, y: Double, stretch: Double, glow: Double)
        let phase: Double
        /// How much it swells on the beat.
        let beat: Double
    }

    private static let blobs: [Blob] = [
        Blob(frame: CGRect(x: -60, y: -10, width: 280, height: 260), color: Color(hex: 0xC4183A),
             opacity: 0.38, blur: 40, periods: (23, 17, 29, 19), phase: 0.0, beat: 0.035),
        Blob(frame: CGRect(x: 180, y: -40, width: 240, height: 220), color: Color(hex: 0x6B3FA0),
             opacity: 0.32, blur: 35, periods: (27, 19, 21, 23), phase: 1.7, beat: 0.03),
        Blob(frame: CGRect(x: 60, y: 60, width: 200, height: 180), color: Color(hex: 0xE0206A),
             opacity: 0.22, blur: 30, periods: (19, 23, 17, 29), phase: 3.1, beat: 0.05),
        Blob(frame: CGRect(x: 230, y: 140, width: 180, height: 180), color: Color(hex: 0x3B1F7A),
             opacity: 0.28, blur: 25, periods: (31, 21, 25, 17), phase: 4.4, beat: 0.025),
        Blob(frame: CGRect(x: -20, y: 180, width: 160, height: 160), color: Color(hex: 0x9B7FD4),
             opacity: 0.14, blur: 27.5, periods: (21, 29, 19, 27), phase: 5.6, beat: 0.04),
    ]

    var body: some View {
        Group {
            if reduceMotion {
                clouds(at: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !(isPlaying || isSettling))) { context in
                    clouds(at: context.date)
                }
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .offset(y: Self.top - Self.marginAbove)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            clock = DriftClock(isRunning: isPlaying)
        }
        .onChange(of: isPlaying) { _, playing in
            clock.set(running: playing, at: Date())
            guard !playing else { return }
            isSettling = true
            Task {
                try? await Task.sleep(for: .seconds(DriftClock.ramp))
                isSettling = false
            }
        }
    }

    /// `date` nil draws them still, as in Figma.
    private func clouds(at date: Date?) -> some View {
        let time = date.map { clock.time(at: $0) } ?? 0
        let energy = date.map { clock.speed(at: $0) } ?? (isPlaying ? 1 : 0)
        // The beat runs on the clock the equalizer uses, so both swell
        // together — a light touch on top of the drift.
        let beat = date.map { RadioPulse.beat(at: $0.timeIntervalSinceReferenceDate) } ?? 0
        let drift = date == nil ? 0.0 : 1.0
        return Canvas { context, size in
            let scale = size.width / Self.designWidth
            for (index, blob) in Self.blobs.enumerated() {
                let seed = Double(index) * 7.31 + blob.phase
                // Wandering: on each axis three slow waves whose periods
                // are in irrational ratios (1 : φ : √5), so a cloud's path
                // never closes on itself and the picture never repeats.
                let dx = drift * 70 * Self.wander(time, period: blob.periods.x, seed: seed)
                let dy = drift * (-10 + 38 * Self.wander(time, period: blob.periods.y, seed: seed + 3.7))
                let stretch = drift * 0.22 * Self.wander(time, period: blob.periods.stretch, seed: seed + 9.1)
                let turn = drift * 0.5 * Self.wander(time, period: blob.periods.stretch * 1.7, seed: seed + 5.3)
                let glow = 1 + drift * 0.22 * Self.wander(time, period: blob.periods.glow, seed: seed + 2.2)
                    + 2 * blob.beat * beat * energy
                let swell = 1 + blob.beat * beat * energy
                // Paused, a little dimmer.
                let opacity = blob.opacity * glow * (0.72 + 0.28 * energy)

                let center = CGPoint(
                    x: (blob.frame.midX + dx) * scale,
                    y: blob.frame.midY + dy + Self.marginAbove
                )
                let cloud = CGSize(
                    width: blob.frame.width * scale * (1 + stretch) * swell,
                    height: blob.frame.height * (1 - stretch * 0.8) * swell
                )

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: blob.blur))
                    layer.opacity = min(max(opacity, 0), 1)
                    layer.translateBy(x: center.x, y: center.y)
                    layer.rotate(by: .radians(turn))
                    // Not one ellipse but three, overlapping and sliding
                    // against each other: blurred, the cloud's outline
                    // swells out on one side and draws in on another, so it
                    // morphs like smoke rather than just moving.
                    for lobe in 0..<3 {
                        let lobeSeed = seed + Double(lobe) * 11.7
                        let reach = lobe == 0 ? 0 : drift * 0.22
                        let ox = reach * cloud.width * Self.wander(time, period: blob.periods.y * 0.8, seed: lobeSeed)
                        let oy = reach * cloud.height * Self.wander(time, period: blob.periods.x * 0.9, seed: lobeSeed + 1.9)
                        let shrink = lobe == 0 ? 1 : 0.62 + drift * 0.1 * Self.wander(time, period: blob.periods.glow, seed: lobeSeed + 4.4)
                        let w = cloud.width * shrink
                        let h = cloud.height * shrink
                        layer.fill(Path(ellipseIn: CGRect(x: ox - w / 2, y: oy - h / 2, width: w, height: h)),
                                   with: .color(blob.color))
                    }
                }
            }
        }
    }

    /// Smooth, never-repeating motion in about -1…1: three sines with
    /// periods `period`, `period`·φ and `period`·√5.
    private static func wander(_ time: Double, period: Double, seed: Double) -> Double {
        let a = sin(2 * .pi * time / period + seed)
        let b = sin(2 * .pi * time / (period * 1.618_034) + seed * 1.7)
        let c = sin(2 * .pi * time / (period * 2.236_068) + seed * 2.3)
        return 0.55 * a + 0.3 * b + 0.15 * c
    }
}

/// Time that runs only while the radio plays: it speeds up from a stop
/// and slows down to one over `ramp` seconds, so whatever it drives
/// glides to a halt and on again without a jump.
private struct DriftClock {
    static let ramp: TimeInterval = 1.6

    /// The clock's reading and speed (0…1) at `anchorDate`, and the speed
    /// it's heading for.
    private var anchorTime: TimeInterval = 0
    private var anchorSpeed: Double = 0
    private var targetSpeed: Double = 0
    private var anchorDate = Date()

    init(isRunning: Bool = false) {
        anchorSpeed = isRunning ? 1 : 0
        targetSpeed = anchorSpeed
    }

    mutating func set(running: Bool, at date: Date) {
        anchorTime = time(at: date)
        anchorSpeed = speed(at: date)
        targetSpeed = running ? 1 : 0
        anchorDate = date
    }

    func speed(at date: Date) -> Double {
        let u = progress(at: date)
        return anchorSpeed + (targetSpeed - anchorSpeed) * (u * u * (3 - 2 * u))
    }

    /// The integral of `speed`: smoothstep's integral is u³ - u⁴/2.
    func time(at date: Date) -> TimeInterval {
        let elapsed = max(0, date.timeIntervalSince(anchorDate))
        let ramped = min(elapsed, Self.ramp)
        let u = ramped / Self.ramp
        let during = anchorSpeed * ramped + (targetSpeed - anchorSpeed) * Self.ramp * (u * u * u - u * u * u * u / 2)
        return anchorTime + during + targetSpeed * max(0, elapsed - Self.ramp)
    }

    private func progress(at date: Date) -> Double {
        min(max(date.timeIntervalSince(anchorDate) / Self.ramp, 0), 1)
    }
}
