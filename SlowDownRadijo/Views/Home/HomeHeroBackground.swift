import SwiftUI

/// Blurred hero band behind the home screen's header — the current show's
/// own artwork (`NowPlayingViewModel.showArtwork`, or a dedicated bundled
/// photo for "The Best of Slow Down" — see `HomeView.heroImage`), softened
/// and vignetted into `Theme.background` on both sides and along the
/// bottom so the header buttons and the content below stay legible.
/// Renders nothing when `image` is `nil` — the caller is responsible for
/// deciding when that's appropriate (no `imageURL` on the current show).
struct HomeHeroBackground: View {
    let image: UIImage?

    static let height: CGFloat = 233

    var body: some View {
        if let image {
            GeometryReader { proxy in
                // Figma's own "Image" layer doesn't use a flat blur — it's a
                // *progressive* (radial) blur effect: radius 0 at the
                // center, ramping up to 34 toward the edges. The design-
                // context export can't represent that (it flattens to a
                // single `blur-[17px]`, exactly the midpoint of 0 and 34),
                // which is why an earlier uniform `.blur(radius:)` pass
                // either smeared the whole image or, tuned down, lost the
                // intended sharp-center/soft-edge depth entirely. This
                // reproduces the real effect: a sharp base image, with a
                // second blurred copy masked in via a radial gradient so
                // it's invisible at the center (revealing the sharp layer
                // beneath) and fully opaque toward the corners.
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            // Same "SwiftUI blur reads stronger than Figma's
                            // nominal value" gap as before — Figma's 34 max
                            // radius, applied literally, over-smeared the
                            // edges. Tuned down empirically the same way.
                            .blur(radius: 14)
                            .mask {
                                RadialGradient(
                                    colors: [.clear, .black],
                                    center: .center,
                                    startRadius: proxy.size.width * 0.12,
                                    endRadius: proxy.size.width * 0.62
                                )
                            }
                    }
            }
            .frame(height: Self.height)
            .overlay {
                // Three stacked gradients, matching the Figma source's
                // exact stop percentages (re-verified 2026-08-23 against
                // the Fill panel directly, since the CSS export's values
                // had drifted from the file's current state): darken the
                // right edge (behind the header buttons), darken the left
                // edge (behind the logo), then darken the bottom so the
                // image blends into the page background below rather than
                // cutting off sharply.
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0), location: 0.74),
                        .init(color: Theme.background, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    stops: [
                        .init(color: Theme.background, location: 0),
                        .init(color: Theme.background.opacity(0), location: 0.54)
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
