import SwiftUI

/// How many times the listener has tapped the already selected tab — set
/// per page by `RootTabView`, read by `.scrollsToTopOnTabReselect()`.
private struct TabReselectCountKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var tabReselectCount: Int {
        get { self[TabReselectCountKey.self] }
        set { self[TabReselectCountKey.self] = newValue }
    }
}

/// Tapping the current tab again scrolls its page back to the top, as in
/// the system tab bar. Put it on the page's scroll content (the stack
/// directly inside the `ScrollView`).
private struct ScrollsToTopOnTabReselect: ViewModifier {
    @Environment(\.tabReselectCount) private var reselectCount
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let topID = "tab-page-top"

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .id(Self.topID)
                .onChange(of: reselectCount) { _, _ in
                    withAnimation(reduceMotion ? nil : Motion.smoothOut(Motion.slow)) {
                        proxy.scrollTo(Self.topID, anchor: .top)
                    }
                }
        }
    }
}

extension View {
    func scrollsToTopOnTabReselect() -> some View {
        modifier(ScrollsToTopOnTabReselect())
    }
}
