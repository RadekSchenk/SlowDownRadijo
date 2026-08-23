import SwiftUI

/// "Moderuje" kicker + host name + a small rounded-square headshot, shown
/// opposite the ON-AIR badge for hosted shows. Rotation blocks like "The
/// Best of Slow Down" have no host and simply omit this. Photos are
/// bundled in `Assets.xcassets` rather than loaded remotely.
struct HostBadge: View {
    let name: String
    let imageName: String?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.hostedByKicker)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                Text(name.uppercased())
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 31, height: 31)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}
