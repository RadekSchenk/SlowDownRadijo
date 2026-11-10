import SwiftUI

/// Keeps `AppHeaderView` (MENU and ON-AIR) where it is while the page
/// scrolls under it, rather than travelling up with the page.
///
/// The page puts an `AppHeaderSpacer` where the header used to be — the
/// same room, so nothing below moves — and the scroll view gets
/// `.pinnedAppHeader()`, which lays the real header over the top. Once the
/// page has moved up, a short fade from the page's background sits behind
/// the header so the content passing beneath doesn't run through MENU and
/// ON-AIR; at rest it's gone, and whatever is behind the header (the home
/// screen's clouds) shows through as before.
extension View {
    /// For a vertical `ScrollView` that ignores the top safe area, with an
    /// `AppHeaderSpacer` at the top of its content.
    func pinnedAppHeader() -> some View {
        modifier(PinnedAppHeader())
    }
}

/// The header's room in the page: `AppHeaderView.topInset` plus its own
/// height. Reports where it is, so `pinnedAppHeader()` knows how far the
/// page has scrolled.
struct AppHeaderSpacer: View {
    var body: some View {
        Color.clear
            .frame(height: AppHeaderView.height)
            .padding(.top, AppHeaderView.topInset)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: HeaderScrollOffsetKey.self,
                                           value: proxy.frame(in: .scrollView).minY)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct HeaderScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PinnedAppHeader: ViewModifier {
    /// The spacer's top in the scroll view: 0 at rest, negative once the
    /// page has moved up, positive while it's pulled down.
    @State private var offset: CGFloat = 0

    /// How far the page moves before the backdrop is fully there.
    private static let fadeDistance: CGFloat = 40

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(HeaderScrollOffsetKey.self) { offset = $0 }
            .overlay(alignment: .top) {
                AppHeaderView()
                    .padding(.horizontal, 20)
                    .padding(.top, AppHeaderView.topInset)
                    .background(alignment: .top) {
                        LinearGradient(
                            stops: [
                                .init(color: Theme.background, location: 0),
                                .init(color: Theme.background, location: 0.62),
                                .init(color: Theme.background.opacity(0), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: AppHeaderView.topInset + AppHeaderView.height + 28)
                        .opacity(min(max(-offset / Self.fadeDistance, 0), 1))
                        .allowsHitTesting(false)
                    }
                    .ignoresSafeArea(edges: .top)
            }
    }
}
