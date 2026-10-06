import SwiftUI

/// Back-navigation header for screens pushed inside the menu sheet (the app
/// hides the system nav bar everywhere): a header-pill back button + a
/// title at the home screen's 24pt section-heading scale.
struct BackHeaderView: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HeaderIconButton(systemName: "chevron.left", action: onBack)

            Text(title)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}
