import SwiftUI

extension View {
    /// The view scrolls with its page as usual, and fades out as it leaves
    /// under the top of the screen instead of being cut off by the status
    /// bar: the fade starts once its top edge passes `startingAt` (from
    /// the top of the screen) and ends as its bottom edge reaches
    /// `fadeEnd`. A view resting above the default line passes its resting
    /// position, so it stays clear until the page moves. With
    /// `shrinkingTo` below 1 it also shrinks towards its bottom edge, the
    /// way cover art in Spotify recedes — staying attached to what follows
    /// it on the page. With Reduce Motion it only fades.
    ///
    /// For views directly in a vertical `ScrollView`.
    func fadesOutUnderTopEdge(startingAt fadeStart: CGFloat = 120, shrinkingTo smallestScale: CGFloat = 1) -> some View {
        modifier(ScrollEdgeFade(fadeStart: fadeStart, smallestScale: smallestScale))
    }
}

private struct ScrollEdgeFade: ViewModifier {
    /// From the top of the scroll view, which on these pages is the top of
    /// the screen: by default a little below the status bar…
    let fadeStart: CGFloat
    let smallestScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// …to behind it.
    private static let fadeEnd: CGFloat = 40

    func body(content: Content) -> some View {
        content.visualEffect { [reduceMotion, fadeStart, smallestScale] view, proxy in
            let top = proxy.frame(in: .scrollView).minY
            let travel = proxy.size.height + fadeStart - Self.fadeEnd
            let progress = min(max((fadeStart - top) / travel, 0), 1)
            return view
                .scaleEffect(reduceMotion ? 1 : 1 - (1 - smallestScale) * progress, anchor: .bottom)
                // Slow to start, so a view just reaching the line stays
                // clear and only goes faint behind the status bar.
                .opacity(1 - pow(progress, 1.5))
        }
    }
}
