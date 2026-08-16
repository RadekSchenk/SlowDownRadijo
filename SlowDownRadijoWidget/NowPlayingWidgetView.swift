import SwiftUI
import WidgetKit

/// Deliberately uses system fonts rather than `Theme.Typography.Manrope` —
/// the custom Manrope font files are registered via the host app's
/// `UIAppFonts` Info.plist key, which this extension's own bundle doesn't
/// share. `Theme`'s colors have no such dependency, so those are reused
/// as-is for brand consistency.
struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowPlayingEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            Theme.background
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            onAirBadge
            Spacer(minLength: 0)
            Text(entry.show?.name ?? L10n.widgetFallbackTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if let hostName = entry.show?.hostName {
                Text(hostName.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                onAirBadge
                Text(entry.show?.name ?? L10n.widgetFallbackTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let title = entry.latestTitle, let artist = entry.latestArtist {
                    Text("\(title) · \(artist)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.lavender)
                        .lineLimit(1)
                } else if let hostName = entry.show?.hostName {
                    Text(hostName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder
    private var artwork: some View {
        if let imageName = entry.show?.hostImageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 46)
        }
    }

    private var onAirBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0.85, green: 0.12, blue: 0.12))
                .frame(width: 7, height: 7)
            Text(L10n.widgetOnAir)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.12, blue: 0.12))
        }
    }
}

/// Small, self-contained copy of just the two strings this widget needs —
/// not the full `L10n` enum, since that reads `LocalizationManager`'s
/// `UserDefaults.standard` preference, which this extension's sandboxed
/// container doesn't share with the host app (no App Group is set up for
/// this widget). Defaults to Czech, matching the station's own default.
private enum L10n {
    static let widgetOnAir = "ON AIR"
    static let widgetFallbackTitle = "Slow Down Rádijo"
}
