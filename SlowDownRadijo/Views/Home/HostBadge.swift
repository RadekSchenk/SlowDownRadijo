import SwiftUI

/// Host name + circular headshot, shown opposite the ON-AIR badge for
/// hosted shows. Rotation blocks like "The Best of Slow Down" have no host
/// and simply omit this. Photos are bundled in `Assets.xcassets` rather
/// than loaded remotely.
struct HostBadge: View {
    let name: String
    let imageName: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(name.uppercased())
                .font(Theme.Typography.Manrope.bold(size: 12))
                .foregroundStyle(Theme.gold)
                .lineLimit(1)

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
