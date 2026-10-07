import SwiftUI

/// One platform row — logo, name, price, and a CTA. Laid out like a row of
/// the home screen's "Pořady" list (title + subtle detail line, 20pt
/// vertical padding, dividers drawn by `SupportView`); the CTA uses the
/// header's pill geometry filled with `Theme.liveRed`.
struct SupportCardView: View {
    @ObservedObject private var loc = LocalizationManager.shared

    let option: SupportOption
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(option.logoAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.name)
                    .font(Theme.Typography.Manrope.extraBold(size: 21, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
                Text(option.price)
                    .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.subtleText)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button(action: action) {
                Text(L10n.support)
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.liveRed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
    }
}
