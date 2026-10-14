import SwiftUI

/// Persistent masthead used at the top of every tab (Figma "app-header",
/// node 12341:1628): the Menu pill on the left, the ON-AIR badge on the
/// right and the brand mark centred between them — replacing the native
/// navigation bar title across the whole app (see `RootTabView`, which
/// hides the system nav bar).
///
/// "Menu" opens `HubView` as a sheet — settings, news, notifications,
/// feedback and the language switch, rather than surfacing every control
/// directly here.
struct AppHeaderView: View {
    /// Every tab puts the header this far below the true top edge of the
    /// screen (Figma: the 48pt status bar), not at the system safe-area
    /// inset, so it sits at the same height on every tab.
    static let topInset: CGFloat = 48

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isShowingHub = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            menuButton
            Spacer(minLength: 0)
            OnAirBadge()
        }
        // Centred on the screen whatever the two sides measure. Figma lets
        // the 55pt mark stand 10pt above and below the pill row, into the
        // header's padding, so it doesn't make the header taller.
        .overlay {
            // `BrandLogo` is the white wordmark (the app is dark-only).
            Image("BrandLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 66, height: 55)
                .accessibilityHidden(true)
        }
        // Matches the Figma "app-header" frame's own auto-layout padding
        // (20 horizontal — already provided by every tab root's own outer
        // inset, so not repeated here — and 16 vertical).
        .padding(.vertical, Theme.Spacing.md)
        .sheet(isPresented: $isShowingHub) {
            HubView()
                .appTextSizeLimit()
        }
    }

    private var menuButton: some View {
        Button {
            isShowingHub = true
        } label: {
            HStack(spacing: 6) {
                hamburger
                Text(L10n.hubTitle.uppercased())
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.hubTitle)
    }

    /// Three 14 × 2 lines, 2pt apart.
    private var hamburger: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.textPrimary)
                    .frame(width: 14, height: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
