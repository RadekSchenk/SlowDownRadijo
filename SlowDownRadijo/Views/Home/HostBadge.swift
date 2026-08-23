import SwiftUI

/// "Moderuje" kicker + host name + circular headshot, shown opposite the
/// ON-AIR badge for hosted shows. Rotation blocks like "The Best of Slow
/// Down" have no host and simply omit this. Photos are bundled in
/// `Assets.xcassets` rather than loaded remotely.
struct HostBadge: View {
    let name: String
    let imageName: String?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.hostedByKicker)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                Text(name.uppercased())
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)
            }

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }
        }
    }
}
