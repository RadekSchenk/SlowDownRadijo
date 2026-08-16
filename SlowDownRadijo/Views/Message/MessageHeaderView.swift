import SwiftUI

/// The Vzkaz tab's own header (back chevron + centered brand title),
/// distinct from `AppHeaderView` — matches the dedicated recording flow in
/// the Figma redesign rather than the shared masthead used elsewhere.
struct MessageHeaderView: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color(hex: 0x1F1A3F), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("SLOW DOWN RÁDIJO")
                .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .footnote))
                .foregroundStyle(Theme.gold)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}
