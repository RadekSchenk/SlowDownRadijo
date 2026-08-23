import SwiftUI

/// Persistent masthead used at the top of every tab — brand mark + slogan,
/// replacing the native navigation bar title across the whole app (see
/// `RootTabView`, which hides the system nav bar). Matches the Figma
/// "radio-flat-typo" redesign's `app-header`.
///
/// The hamburger icon opens `HubView` as a sheet — settings, news,
/// notifications, and feedback, rather than surfacing every control
/// directly here. The language toggle just left of it is the one
/// exception, since it's a single tap between the app's only two
/// languages and didn't earn a trip through Settings.
struct AppHeaderView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isShowingHub = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image("BrandLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 78, height: 62)

            Text(L10n.tagline)
                .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
                .textCase(.uppercase)
                .foregroundStyle(Theme.gold)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button {
                loc.language = loc.language == .cs ? .en : .cs
            } label: {
                Text(loc.language.displayCode)
                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.hairline(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.settingsLanguageTitle)

            Button {
                isShowingHub = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.hairline(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .sheet(isPresented: $isShowingHub) {
            HubView()
        }
    }
}
