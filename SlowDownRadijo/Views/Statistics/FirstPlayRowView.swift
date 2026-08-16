import SwiftUI

/// A single row in the "Poprvé na rádiu" feed — no artwork lookup (this list
/// can be long-ish and isn't worth an iTunes round-trip per row), just a
/// sparkle glyph to mark "new," title/artist, and a Spotify search link.
struct FirstPlayRowView: View {
    let entry: FirstPlay

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.sunOrange)
                .frame(width: 44, height: 44)
                .background(Theme.sunOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(entry.artist)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.sm)

            if let url = entry.spotifySearchURL {
                SpotifyPillButton(url: url)
            }
        }
    }
}
