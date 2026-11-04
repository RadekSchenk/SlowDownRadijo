import SwiftUI

extension View {
    /// The quieter half of the page's scroll motion, for the content below
    /// the now-playing header: a view coming up from the bottom of the
    /// screen starts a little lower, smaller and fainter and settles into
    /// place as it comes fully into view; on its way out at the top it
    /// fades under the status bar like the header does
    /// (`fadesOutUnderTopEdge`). Both follow the finger rather than run on
    /// their own, so nothing moves while the page rests. With Reduce Motion
    /// it only fades.
    ///
    /// For views directly in a vertical `ScrollView`, no taller than about
    /// half the screen — a taller one would never settle completely.
    func movesWithScroll() -> some View {
        modifier(ScrollReveal())
            .fadesOutUnderTopEdge()
    }
}

private struct ScrollReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far below its place a view starts, at the very bottom edge.
    private static let rise: CGFloat = 24

    func body(content: Content) -> some View {
        content.scrollTransition(.interactive(timingCurve: .easeOut), axis: .vertical) { [reduceMotion] view, phase in
            // 0 once fully in view, 1 at the bottom edge; leaving at the
            // top is the edge fade's job.
            let progress = CGFloat(max(phase.value, 0))
            return view
                .opacity(1 - 0.6 * progress)
                .scaleEffect(reduceMotion ? 1 : 1 - 0.04 * progress, anchor: .top)
                .offset(y: reduceMotion ? 0 : Self.rise * progress)
        }
    }
}
