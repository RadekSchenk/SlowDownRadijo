import SwiftUI

extension View {
    /// The view scrolls with its page as usual, and fades out as it leaves
    /// under the top of the screen instead of being cut off by the status
    /// bar: the fade starts once its top edge passes `fadeStart` and ends
    /// as its bottom edge reaches `fadeEnd`. With `shrinkingTo` below 1 it
    /// also shrinks towards its bottom edge, the way cover art in Spotify
    /// recedes — staying attached to what follows it on the page. With
    /// Reduce Motion it only fades.
    ///
    /// For views directly in a vertical `ScrollView`.
    func fadesOutUnderTopEdge(shrinkingTo smallestScale: CGFloat = 1) -> some View {
        modifier(ScrollEdgeFade(smallestScale: smallestScale))
    }
}

private struct ScrollEdgeFade: ViewModifier {
    let smallestScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// From the top of the scroll view, which on these pages is the top of
    /// the screen: a little below the status bar…
    private static let fadeStart: CGFloat = 120
    /// …to behind it.
    private static let fadeEnd: CGFloat = 40

    func body(content: Content) -> some View {
        content.visualEffect { [reduceMotion, smallestScale] view, proxy in
            let top = proxy.frame(in: .scrollView).minY
            let travel = proxy.size.height + Self.fadeStart - Self.fadeEnd
            let progress = min(max((Self.fadeStart - top) / travel, 0), 1)
            return view
                .scaleEffect(reduceMotion ? 1 : 1 - (1 - smallestScale) * progress, anchor: .bottom)
                // Slow to start, so a view just reaching the line stays
                // clear and only goes faint behind the status bar.
                .opacity(1 - pow(progress, 1.5))
        }
    }
}
