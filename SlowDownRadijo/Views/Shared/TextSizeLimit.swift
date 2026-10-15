import SwiftUI

extension View {
    /// Text grows with the system setting up to XXXL, the largest of the
    /// standard sizes; the accessibility sizes beyond it pushed several
    /// fixed-width rows (and with them whole pages) past the screen's edges.
    /// Checked with the screenshot tests at L, XXXL and AX sizes.
    ///
    /// A sheet doesn't inherit this from the view that presents it, so
    /// every sheet's content applies it again.
    func appTextSizeLimit() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
