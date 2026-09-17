import SwiftUI

/// Persistent masthead used at the top of every tab — brand mark + a CZ/EN
/// language pill + a Menu pill, replacing the native navigation bar title
/// across the whole app (see `RootTabView`, which hides the system nav
/// bar). Matches the 2026-08-23 home-screen hero redesign's `app-header` —
/// no tagline anymore (dropped from all three of that design's variants).
///
/// "Menu" opens `HubView` as a sheet — settings, news, notifications, and
/// feedback, rather than surfacing every control directly here. The
/// language pill and the appearance toggle are the exceptions, since
/// they're each a single tap and didn't earn a trip through Settings.
struct AppHeaderView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var isShowingHub = false

    private var isEffectivelyDark: Bool {
        appearanceManager.isEffectivelyDark(currentSystemScheme: systemColorScheme)
    }

    private var appearanceIconName: String {
        isEffectivelyDark ? "sun.max.fill" : "moon.fill"
    }

    /// Shows the language a tap *switches to*, not the current one — so in
    /// Czech the pill reads "EN" (tap to switch to English), and in
    /// English it reads "CZ" (tap to switch to Czech). Also deliberately
    /// not `AppLanguage.displayCode` ("CS"/"EN"), which stays the
    /// ISO-style code used in the feedback-email diagnostics
    /// (`DeviceInfo`); this is just how the header pill reads.
    private var languagePillLabel: String {
        loc.language == .cs ? "EN" : "CZ"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // `BrandLogo` is an appearance-aware asset (Assets.xcassets) —
            // purple wordmark for Light (legible on the light page
            // background), white wordmark (`BrandLogoDark.png`) for Dark.
            // No `.dark`/`.light` branching needed here; the system picks
            // the right one automatically.
            Image("BrandLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 73, height: 61)

            Spacer(minLength: 0)

            Button {
                appearanceManager.appearance = isEffectivelyDark ? .light : .dark
            } label: {
                Image(systemName: appearanceIconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.settingsAppearanceTitle)

            Button {
                loc.language = loc.language == .cs ? .en : .cs
            } label: {
                Text(languagePillLabel)
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.settingsLanguageTitle)

            Button {
                isShowingHub = true
            } label: {
                Text(L10n.hubTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        // Matches the Figma "app-header" frame's own auto-layout padding
        // (20 horizontal — already provided by every tab root's own outer
        // inset, so not repeated here — and 16 vertical).
        .padding(.vertical, Theme.Spacing.md)
        .sheet(isPresented: $isShowingHub) {
            HubView()
        }
    }
}
