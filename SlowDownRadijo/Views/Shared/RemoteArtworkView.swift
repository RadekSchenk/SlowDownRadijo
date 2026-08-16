import SwiftUI

/// Loads a show/track artwork image with caching (via the shared URLCache
/// that `AsyncImage` uses) and a graceful fallback when the URL is missing
/// or the load fails — the station's own image URLs occasionally 404 or get
/// swapped, so every artwork slot in the app needs this fallback.
struct RemoteArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.card

    var body: some View {
        // `.aspectRatio(contentMode: .fill)` alone reports its *ideal*
        // (potentially screen-exceeding) size upward, which can stretch
        // parent layouts and swallow their padding. GeometryReader pins the
        // image to the exact size this view is given, so it always fills
        // that box and never inflates it.
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            case .failure:
                placeholder
            case .empty:
                if url == nil {
                    placeholder
                } else {
                    loadingView
                }
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.accentGradient.opacity(0.25)
            Theme.surface
            Image(systemName: "waveform")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var loadingView: some View {
        ZStack {
            Theme.surface
            ProgressView()
                .tint(Theme.textSecondary)
        }
    }
}
