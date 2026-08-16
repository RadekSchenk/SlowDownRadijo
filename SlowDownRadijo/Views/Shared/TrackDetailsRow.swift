import SwiftUI

/// Playback state of the optional iTunes-preview button on a
/// `TrackDetailsRow` — see `PreviewPlayerService`.
enum PreviewPlaybackState: Equatable {
    case idle, loading, playing
}

/// Non-nil `favorite`/`preview` on `TrackDetailsRow` opt a row into the
/// bigger "Co hrálo"/Favorites card layout, with a labeled action pill row
/// below the title/artist — both stay `nil` for rows that don't support
/// them (currently just the live now-playing row, which keeps the original
/// compact single-line layout).
struct FavoriteButtonState {
    let isFavorite: Bool
    let action: () -> Void
}

struct PreviewButtonState {
    let playback: PreviewPlaybackState
    let action: () -> Void
}

/// Artwork + title/artist, in one of two layouts depending on whether
/// `favorite`/`preview` are supplied:
/// - Neither: the original compact single-line row (now-playing hero row).
/// - Either: a bigger card — title/artist get room to wrap instead of
///   truncating, and preview/Spotify/favorite become labeled pills on their
///   own row below, wrapping to a second line if they don't all fit.
struct TrackDetailsRow: View {
    let artworkURL: URL?
    let title: String
    let artist: String
    let spotifyURL: URL?
    var cornerRadius: CGFloat = 8
    /// True once iTunes has confirmed it doesn't recognize this track (a
    /// jingle, station ID, DJ mix block — not a real catalogable song).
    /// Hides the whole action-pill row: a preview genuinely can't work,
    /// and favoriting/Spotify-searching something that isn't a real song
    /// doesn't make sense either.
    var hasNoITunesMatch = false
    var favorite: FavoriteButtonState?
    var preview: PreviewButtonState?

    @Environment(\.openURL) private var openURL

    private var isExpanded: Bool { favorite != nil || preview != nil }

    var body: some View {
        if isExpanded {
            expandedBody
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: Theme.Spacing.md) {
            artwork(size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(artist)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: Theme.Spacing.sm)

            if let spotifyURL {
                SpotifyPillButton(url: spotifyURL)
            }
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                artwork(size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.Typography.Manrope.extraBold(size: 18, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(artist)
                        .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.lavender)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            // A confirmed iTunes non-match means this isn't a real,
            // catalogable song (a jingle, station ID, DJ mix block) — a
            // preview genuinely can't work, and favoriting/Spotify-
            // searching it doesn't make sense either, so none of these
            // show at all rather than just the preview button.
            if !hasNoITunesMatch {
                FlowLayout(spacing: Theme.Spacing.sm) {
                    if let preview {
                        ActionPillButton(
                            icon: previewIcon(preview.playback),
                            label: previewLabel(preview.playback),
                            tint: Theme.gold,
                            isLoading: preview.playback == .loading,
                            action: preview.action
                        )
                    }
                    if let favorite {
                        ActionPillButton(
                            icon: favorite.isFavorite ? "heart.fill" : "heart",
                            label: favorite.isFavorite ? L10n.favoriteRemoveAction : L10n.favoriteAddAction,
                            tint: Theme.gold,
                            action: favorite.action
                        )
                    }
                    if let spotifyURL {
                        ActionPillButton(icon: "arrow.up.right", label: L10n.spotifyFindAction, tint: Theme.brandPurple) {
                            openURL(spotifyURL)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .overlay(
            // `.allowsHitTesting(false)` is load-bearing: an overlaid Shape
            // is hit-testable across its whole (geometric, not just drawn)
            // area by default even when only stroked, which — sitting in
            // front of the action pills below in z-order — silently
            // swallowed every tap meant for them. Decorative-only border,
            // so it must not intercept touches.
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private func artwork(size: CGFloat) -> some View {
        RemoteArtworkView(url: artworkURL, cornerRadius: cornerRadius)
            .frame(width: size, height: size)
            .id(artworkURL)
            .transition(.opacity)
    }

    private func previewIcon(_ playback: PreviewPlaybackState) -> String {
        switch playback {
        case .idle, .loading: return "play.circle.fill"
        case .playing: return "stop.circle.fill"
        }
    }

    private func previewLabel(_ playback: PreviewPlaybackState) -> String {
        switch playback {
        case .idle: return L10n.previewPlayAction
        case .loading: return L10n.previewLoadingAction
        case .playing: return L10n.previewStopAction
        }
    }
}

/// A labeled, pill-shaped action button — icon + text, used for the
/// preview/Spotify/favorite row below a `TrackDetailsRow`'s expanded card.
private struct ActionPillButton: View {
    let icon: String
    let label: String
    var tint: Color = Theme.lavender
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(label)
                    .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                Capsule().strokeBorder(tint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// Lays out its children left-to-right, wrapping onto a new line whenever
/// the next child wouldn't fit in the remaining width — used so the
/// preview/Spotify/favorite pills below a track row sit on one line when
/// there's room and wrap onto a second when there isn't (e.g. a longer
/// title pushing the card to a narrower device, or larger Dynamic Type).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)

        return CGSize(width: maxWidth.isFinite ? maxWidth : widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
