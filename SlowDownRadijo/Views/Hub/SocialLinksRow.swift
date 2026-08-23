import SwiftUI

/// The station's own social presence — same four platforms, same order, as
/// the icon row at the very top of slowdownradijo.cz. Icons are simplified,
/// monochrome interpretations rather than each platform's official brand
/// mark/color, matching this app's existing convention of keeping
/// third-party touchpoints in its own visual language (see
/// `SpotifyPillButton`, which does the same for the Spotify CTA).
struct SocialLinksRow: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 0)
            button(urlString: "https://www.youtube.com/@slowdownradijo", label: "YouTube") {
                YouTubeGlyph()
            }
            button(urlString: "https://www.threads.com/@slowdownradijocz", label: "Threads") {
                Image(systemName: "at")
                    .font(.system(size: 19, weight: .semibold))
            }
            button(urlString: "https://www.instagram.com/slowdownradijocz", label: "Instagram") {
                InstagramGlyph()
            }
            button(urlString: "https://www.facebook.com/slowdownradijo/", label: "Facebook") {
                Text("f")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 0)
        }
    }

    private func button(urlString: String, label: String, @ViewBuilder icon: () -> some View) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            icon()
                .foregroundStyle(Theme.lavender)
                .frame(width: 44, height: 44)
                .background(Theme.hairline(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
