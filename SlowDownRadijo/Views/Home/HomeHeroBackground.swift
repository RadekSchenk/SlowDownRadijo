import SwiftUI

/// Blurred hero band behind the home screen's header — the current show's
/// own artwork (`NowPlayingViewModel.showArtwork`), softened and vignetted
/// into `Theme.background` on both sides and along the bottom so the
/// header buttons and the content below stay legible. Renders nothing when
/// `image` is `nil` — the caller is responsible for deciding when that's
/// appropriate (no `imageURL` on the current show, or a show the design
/// deliberately excludes, e.g. "The Best of Slow Down" — see `HomeView`).
struct HomeHeroBackground: View {
    let image: UIImage?

    static let height: CGFloat = 233

    var body: some View {
        if let image {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    // Scaled up before blurring so the blur's soft edge
                    // falls outside the visible frame instead of showing a
                    // faint halo at the image's true bounds.
                    .scaleEffect(1.15)
                    .blur(radius: 17)
                    .clipped()
            }
            .frame(height: Self.height)
            .overlay {
                // Three stacked gradients, matching the Figma source
                // exactly: darken the right edge (behind the header
                // buttons), darken the left edge (behind the logo), then
                // darken the bottom so the image blends into the page
                // background below rather than cutting off sharply.
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0), location: 0.708),
                        .init(color: Theme.background, location: 0.963)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    stops: [
                        .init(color: Theme.background, location: 0),
                        .init(color: Theme.background.opacity(0), location: 0.538)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0), location: 0.5),
                        .init(color: Theme.background, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: Self.height)
            .clipped()
        }
    }
}
