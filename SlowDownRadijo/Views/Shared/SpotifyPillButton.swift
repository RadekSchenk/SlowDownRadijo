import SwiftUI

/// Outlined gold "Spotify" pill — the search-based CTA used on every track
/// row (history rows and the now-playing row alike).
struct SpotifyPillButton: View {
    let url: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
            Text(L10n.spotify)
                .font(Theme.Typography.Manrope.bold(size: 10, relativeTo: .caption2))
                .foregroundStyle(Theme.gold)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().strokeBorder(Theme.gold, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
