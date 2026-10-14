import SwiftUI

/// Title + optional detail line + leading/trailing accessories, laid out
/// like a row of the home screen's "Pořady" list (20pt vertical padding,
/// extraBold title, `Theme.subtleText` detail). Dividers are drawn by the
/// containing list with `ListDivider`.
struct ListRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            leading

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 18, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.subtleText)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            trailing
        }
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}

extension ListRow where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

/// Trailing "navigates somewhere" marker — the home screen's white 16pt chevron.
struct ListRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
    }
}

/// Leading icon chip — the home screen's ON-AIR badge treatment
/// (`Theme.liveRed` glyph on a 15% tint, 8pt corners).
struct ListRowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.liveRed)
            .frame(width: 44, height: 44)
            .background(Theme.liveRed.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
