import SwiftUI

/// Custom back-navigation header for screens pushed inside the Domeček
/// hub sheet (Settings, News list, News detail) — the app hides the
/// system nav bar everywhere, so this replaces it with a chevron chip +
/// title matching the app's own flat visual language instead of default
/// system chrome.
struct BackHeaderView: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Theme.hairline(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            Text(title)
                .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}
