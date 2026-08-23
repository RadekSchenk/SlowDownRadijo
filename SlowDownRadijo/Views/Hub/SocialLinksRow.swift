import SwiftUI

/// The station's own social presence — same four platforms, same order, as
/// the icon row at the very top of slowdownradijo.cz. Icons are simplified,
/// monochrome interpretations rather than each platform's official brand
/// mark/color, matching this app's existing convention of keeping
/// third-party touchpoints in its own visual language (see
/// `SpotifyPillButton`, which does the same for the Spotify CTA).
struct SocialLinksRow: View {
    @Environment(\.openURL) private var openURL
    /// Keyed by the same platform ids used in `backend/supabase/sql/
    /// 005_social_stats.sql` / `update-social-stats` — "youtube",
    /// "instagram", "facebook", "threads". Missing key (before the fetch
    /// resolves, or if that one platform's scrape failed on the backend's
    /// last refresh cycle) just means no caption shows for that icon —
    /// graceful, not an error state worth surfacing to the user.
    @State private var followerCounts: [String: Int] = [:]

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 0)
            button(urlString: "https://www.youtube.com/@slowdownradijo", label: "YouTube", platform: "youtube") {
                YouTubeGlyph()
            }
            button(urlString: "https://www.threads.com/@slowdownradijocz", label: "Threads", platform: "threads") {
                Image(systemName: "at")
                    .font(.system(size: 19, weight: .semibold))
            }
            button(urlString: "https://www.instagram.com/slowdownradijocz", label: "Instagram", platform: "instagram") {
                InstagramGlyph()
            }
            button(urlString: "https://www.facebook.com/slowdownradijo/", label: "Facebook", platform: "facebook") {
                Text("f")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 0)
        }
        .task {
            // Cached table, refreshed by a backend cron job (see
            // update-social-stats) — cheap to read on every menu open,
            // unlike scraping each platform live from the app itself.
            followerCounts = (try? await SocialStatsService.fetchAll())?
                .reduce(into: [:]) { $0[$1.platform] = $1.followerCount } ?? [:]
        }
    }

    private func button(urlString: String, label: String, platform: String, @ViewBuilder icon: () -> some View) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            VStack(spacing: 4) {
                icon()
                    .foregroundStyle(Theme.lavender)
                    .frame(width: 44, height: 44)
                    .background(Theme.hairline(0.08), in: Circle())

                if let count = followerCounts[platform] {
                    Text(Self.compactCount(count))
                        .font(Theme.Typography.Manrope.semibold(size: 11, relativeTo: .caption2))
                        .foregroundStyle(Theme.lavender)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(followerCounts[platform].map { "\(label), \($0) \(L10n.followersAccessibilitySuffix)" } ?? label)
    }

    private static func compactCount(_ count: Int) -> String {
        switch count {
        case 1_000_000...:
            return String(format: "%.1fM", Double(count) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fk", Double(count) / 1_000)
        default:
            return "\(count)"
        }
    }
}

private struct YouTubeGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(lineWidth: 1.5)
                .frame(width: 23, height: 16)
            PlayTriangle()
                .frame(width: 8, height: 9)
                .offset(x: 1)
        }
    }
}

private struct InstagramGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(lineWidth: 1.5)
                .frame(width: 21, height: 21)
            Circle()
                .strokeBorder(lineWidth: 1.5)
                .frame(width: 10, height: 10)
            Circle()
                .frame(width: 2.5, height: 2.5)
                .offset(x: 5.5, y: -5.5)
        }
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
