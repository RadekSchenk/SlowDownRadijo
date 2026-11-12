import SwiftUI
import UIKit

/// A show's square photo at a given size: the bundled one
/// (`Show.artworkName`) where the show has it, else the web's
/// (`Show.imageURL`, cropped to the square from its centre), else — and
/// while that loads — `ShowArtworkPlaceholder`. The same picture the home
/// screen's cover shows for the show on air.
struct ShowArtworkView: View {
    let show: Show
    let size: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        artwork
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if let name = show.artworkName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        } else if let url = show.imageURL {
            AsyncImage(url: url, transaction: Transaction(animation: Motion.smoothOut(Motion.fast))) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .transition(.opacity)
                } else {
                    ShowArtworkPlaceholder(cornerRadius: 0)
                }
            }
        } else {
            ShowArtworkPlaceholder(cornerRadius: 0)
        }
    }
}
