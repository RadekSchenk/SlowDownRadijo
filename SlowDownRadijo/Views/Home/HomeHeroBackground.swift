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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    // No extra `.scaleEffect` here — it would visually
                    // magnify the blur past its nominal radius (the blur is
                    // rasterized first, then the scale enlarges those soft
                    // pixels too). `.aspectRatio(.fill)` already overflows
                    // the frame on its own whenever the source photo's
                    // aspect ratio doesn't match this band's, which is
                    // enough overflow for `.clipped()` to hide the blur's
                    // soft edge without a separate scale step.
                    // The Figma spec says `blur-[17px]`, but SwiftUI's
                    // `.blur(radius:)` reads much stronger than a CSS blur
                    // of the same nominal value against a real (non-studio)
                    // source photo — 17 turned the show photo into an
                    // unrecognizable color smear. Tuned down empirically by
                    // comparing against the actual Figma screenshot until
                    // faces read clearly again, matching the reference.
                    .blur(radius: 2)
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
