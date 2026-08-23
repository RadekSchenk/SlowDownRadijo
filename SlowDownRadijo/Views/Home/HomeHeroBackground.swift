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
    /// The page content's own vertical offset, read by `HomeView` via a
    /// `GeometryReader` + `PreferenceKey` pinned to the `ScrollView`'s
    /// coordinate space — positive while the user pulls down past the top
    /// (pull-to-refresh rubber-banding), negative while scrolling down
    /// through the page (content moving up). Defaults to 0 for previews/
    /// call sites that don't track it, which just renders the plain,
    /// unstretched hero.
    var scrollOffset: CGFloat = 0

    static let height: CGFloat = 320

    /// How much taller than normal to render while rubber-banding, so the
    /// image visibly stretches to cover the gap instead of revealing the
    /// flat page background above it — the classic "stretchy header"
    /// pattern (Instagram/Twitter profile headers do the same thing).
    private var stretch: CGFloat { max(0, scrollOffset) }
    /// Vertical shift applied to the whole hero: while pulled down, exactly
    /// cancels `stretch` so the image's top edge stays pinned at the
    /// screen's true top edge (growing downward isn't enough on its own —
    /// without this the extra height would just push the bottom edge
    /// further down instead of filling the gap above). While scrolling up
    /// through the page, only partially cancels the content's own
    /// movement (35%), so the image visibly lags behind everything else
    /// scrolling past it — the actual parallax effect.
    private var offsetY: CGFloat {
        scrollOffset > 0 ? -stretch : -scrollOffset * 0.35
    }

    var body: some View {
        if let image {
            imageLayer(image)
                .frame(height: Self.height + stretch)
                .clipped()
                .overlay { gradientOverlay }
                .frame(height: Self.height + stretch)
                .clipped()
                .offset(y: offsetY)
        }
    }

    private func imageLayer(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            // Figma's own "Image" layer doesn't use a flat blur — it's a
            // *progressive* (radial) blur effect: radius 0 at the center,
            // ramping up to 34 toward the edges. The design-context export
            // can't represent that (it flattens to a single `blur-[17px]`,
            // exactly the midpoint of 0 and 34), which is why an earlier
            // uniform `.blur(radius:)` pass either smeared the whole image
            // or, tuned down, lost the intended sharp-center/soft-edge
            // depth entirely. This reproduces the real effect: a sharp
            // base image, with a second blurred copy masked in via a
            // radial gradient so it's invisible at the center (revealing
            // the sharp layer beneath) and fully opaque toward the corners.
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
    }

    private var gradientOverlay: some View {
        // Three stacked gradients, matching the Figma source's exact stop
        // percentages (right-edge one re-verified again 2026-08-23, now
        // 56%->100% — was 74%->100% just a couple commits ago; the user
        // keeps tuning it directly in Figma, so always re-check against a
        // fresh screenshot rather than trusting this comment's own
        // history): darken the right edge (behind the header buttons),
        // darken the left edge (behind the logo), then darken the bottom
        // so the image blends into the page background below rather than
        // cutting off sharply.
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Theme.background.opacity(0), location: 0.56),
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
    }
}
