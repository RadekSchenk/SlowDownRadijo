import SwiftUI

/// Micro-interaction motion ported from the transitions.dev library
/// (https://transitions.dev/library.html) to SwiftUI, with the library's own
/// numbers: durations, easing curves, distances and blur radii are the
/// values from its token sheet. Each piece names the library item ("P9 —
/// Number pop-in", …) it comes from.
enum Motion {
    // MARK: Tokens (library: --duration-*, --ease-*, --distance-*, --blur-*)

    static let stagger = 0.04
    static let micro = 0.08
    static let quick = 0.15
    static let fast = 0.25
    static let medium = 0.35
    static let slow = 0.40
    static let verySlow = 0.50

    /// `--ease-smooth-out`: cubic-bezier(0.22, 1, 0.36, 1).
    static func smoothOut(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }

    static func easeInOut(_ duration: Double) -> Animation {
        .easeInOut(duration: duration)
    }

    static let distanceMicro: CGFloat = 4
    static let distanceBase: CGFloat = 8
    static let blurSmall: CGFloat = 2

    // MARK: Per-item values

    /// P9 — Number pop-in: 500ms, cubic-bezier(0.34, 1.45, 0.64, 1) (a little
    /// overshoot), 8px travel, 2px blur, 70ms between digits.
    static let numberPop = Animation.timingCurve(0.34, 1.45, 0.64, 1, duration: verySlow)
    static let numberPopStagger = 0.07

    /// P16 — Tabs with a sliding active indicator: 250ms smooth-out.
    static let tabsSliding = smoothOut(fast)

    /// P21 — Accordion: 250ms smooth-out for the panel and the chevron.
    static let accordion = smoothOut(fast)

    /// P4 — Card resize: 300ms smooth-out (used for bars and fills that grow).
    static let cardResize = smoothOut(0.30)

    /// P5 — Icon swap: 250ms ease-in-out, from 25% scale with a 2px blur.
    static let iconSwap = easeInOut(fast)

    /// P10 — Success check: bob uses cubic-bezier(0.34, 1.35, 0.64, 1).
    static let checkBob = Animation.timingCurve(0.34, 1.35, 0.64, 1, duration: verySlow)
}

// MARK: - P9 · Number pop-in

/// Text whose digits pop in when they change: the new digit rises 8px from
/// below out of a 2px blur, the old one lifts away the same way, 70ms apart
/// per digit, with the library's slight overshoot. Everything that is not a
/// digit stays still — "Pořad končí za 38 minut" only animates the 38.
///
/// Single-line only. Falls back to an instant swap with Reduce Motion.
struct PopNumberText: View {
    let text: String
    let font: Font
    var color: Color = Theme.textPrimary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece: Identifiable {
        let id: Int
        let text: String
        let isDigit: Bool
        /// Position among the digits, for the stagger.
        let digitIndex: Int
    }

    /// Digits become their own pieces; runs of anything else stay one piece.
    private var pieces: [Piece] {
        var result: [Piece] = []
        var run = ""
        var digitCount = 0
        func flushRun() {
            guard !run.isEmpty else { return }
            result.append(Piece(id: result.count, text: run, isDigit: false, digitIndex: 0))
            run = ""
        }
        for character in text {
            if character.isASCII && character.isNumber {
                flushRun()
                result.append(Piece(id: result.count, text: String(character), isDigit: true, digitIndex: digitCount))
                digitCount += 1
            } else {
                run.append(character)
            }
        }
        flushRun()
        return result
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(pieces) { piece in
                if piece.isDigit {
                    digit(piece)
                } else {
                    Text(piece.text)
                        .font(font)
                        .foregroundStyle(color)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// One digit slot: a new character replaces the old one in place (the
    /// `ZStack` makes the two overlap instead of sitting side by side).
    private func digit(_ piece: Piece) -> some View {
        let delay = Motion.numberPopStagger * Double(min(piece.digitIndex, 2))
        return ZStack {
            Text(piece.text)
                .font(font)
                .foregroundStyle(color)
                .id(piece.text)
                .transition(Self.transition)
        }
        .animation(reduceMotion ? nil : Motion.numberPop.delay(delay), value: piece.text)
    }

    private static let transition = AnyTransition.asymmetric(
        insertion: .modifier(
            active: PopEffect(offsetY: Motion.distanceBase, blur: Motion.blurSmall, opacity: 0),
            identity: PopEffect(offsetY: 0, blur: 0, opacity: 1)
        ),
        removal: .modifier(
            active: PopEffect(offsetY: -Motion.distanceBase, blur: Motion.blurSmall, opacity: 0),
            identity: PopEffect(offsetY: 0, blur: 0, opacity: 1)
        )
    )
}

private struct PopEffect: ViewModifier {
    let offsetY: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - P5 · Icon swap

extension AnyTransition {
    /// P5 — Icon swap: scales up from 25% (and back down) through a 2px blur.
    static var iconSwap: AnyTransition {
        .modifier(
            active: IconSwapEffect(scale: 0.25, blur: Motion.blurSmall, opacity: 0),
            identity: IconSwapEffect(scale: 1, blur: 0, opacity: 1)
        )
    }
}

private struct IconSwapEffect: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - P22 · Reveal

extension AnyTransition {
    /// P22 — Toast open / close, as a generic reveal: fades in through a 2px
    /// blur while growing from 97% out of its bottom edge.
    static var reveal: AnyTransition {
        .modifier(
            active: RevealEffect(scale: 0.97, blur: Motion.blurSmall, opacity: 0),
            identity: RevealEffect(scale: 1, blur: 0, opacity: 1)
        )
    }
}

private struct RevealEffect: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .bottom)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - P15 · Shimmer text

/// P15 — Shimmer on text: a highlight band sweeps across the glyphs every
/// 2000ms, linear. Used for "still working" texts (connecting, calculating).
struct ShimmerText: View {
    let text: String
    let font: Font
    var base: Color = Theme.mutedText
    var highlight: Color = .white

    private static let period: TimeInterval = 2.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Text(text).font(font).foregroundStyle(base)
        } else {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(time.truncatingRemainder(dividingBy: Self.period) / Self.period)
                Text(text)
                    .font(font)
                    .foregroundStyle(base)
                    .overlay {
                        GeometryReader { proxy in
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.40),
                                    .init(color: highlight, location: 0.50),
                                    .init(color: .clear, location: 0.60),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            // Four text-widths wide, like the library's 400% band.
                            .frame(width: proxy.size.width * 4)
                            .offset(x: proxy.size.width * (-0.8 - 1.4 * phase))
                        }
                        .mask(Text(text).font(font))
                    }
            }
        }
    }
}

// MARK: - P12 · Error shake

/// P12 — Input shake on error: four segments of horizontal travel
/// (0 → +6 → −6 → +4 → 0 pt) over 280ms, each segment on a smooth-out curve.
struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let stops: [(at: CGFloat, x: CGFloat)] = [(0, 0), (0.2857, 6), (0.5714, -6), (0.7857, 4), (1, 0)]
        var x: CGFloat = 0
        for index in 1..<stops.count where progress <= stops[index].at {
            let from = stops[index - 1]
            let to = stops[index]
            let local = (progress - from.at) / (to.at - from.at)
            let eased = 1 - pow(1 - local, 3)
            x = from.x + (to.x - from.x) * eased
            break
        }
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct ShakeOnTrigger: ViewModifier {
    let trigger: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: progress))
            .onChange(of: trigger) { _, isOn in
                guard isOn, !reduceMotion else { return }
                progress = 0
                withAnimation(.linear(duration: 0.28)) { progress = 1 }
            }
    }
}

extension View {
    /// Shakes the view once whenever `trigger` turns true (P12).
    func shake(when trigger: Bool) -> some View {
        modifier(ShakeOnTrigger(trigger: trigger))
    }
}

// MARK: - P10 · Success check

/// P10 — Success check: the circle fades in while rotating from 80° and
/// settling from 40pt below through a 10px blur, and the tick draws itself a
/// beat later — five sub-transitions in parallel, each 500ms.
struct SuccessCheck: View {
    var size: CGFloat = 56
    var color: Color = Color(hex: 0x28C840)

    @State private var fade = false
    @State private var bob = false
    @State private var draw = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.15))
            CheckShape()
                .trim(from: 0, to: draw ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round))
                .padding(size * 0.28)
        }
        .frame(width: size, height: size)
        .opacity(fade ? 1 : 0)
        .rotationEffect(.degrees(fade ? 0 : 80))
        .blur(radius: fade ? 0 : 10)
        .offset(y: bob ? 0 : 40)
        .onAppear {
            if reduceMotion {
                fade = true; bob = true; draw = true
                return
            }
            withAnimation(Motion.smoothOut(Motion.verySlow)) { fade = true }
            withAnimation(Motion.checkBob) { bob = true }
            withAnimation(Motion.smoothOut(Motion.verySlow).delay(Motion.micro)) { draw = true }
        }
        .accessibilityHidden(true)
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.92))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.12))
        return path
    }
}
