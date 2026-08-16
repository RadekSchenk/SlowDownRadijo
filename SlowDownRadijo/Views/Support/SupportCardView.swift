import SwiftUI

/// One row per platform — icon, name, price, and a CTA button. The
/// benefits themselves live once in `SupportView.benefitsSection` (every
/// platform offers the same ones), so this stays a compact picker rather
/// than repeating that list three times.
struct SupportCardView: View {
    @ObservedObject private var loc = LocalizationManager.shared

    let option: SupportOption
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: option.symbolName)
                .font(.system(size: 26))
                .foregroundStyle(Theme.sunOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.name)
                    .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Text(option.price)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.sunOrange)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button(action: action) {
                Text(L10n.support)
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.sunOrange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}
