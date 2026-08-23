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
    /// Vertical offset (from the card's own top edge) of a small speech-
    /// bubble tail pointing left, toward an adjacent time label — see
    /// `HistoryRowView`, the only caller that sets this (a time column sits
    /// to the left there; `FavoritesView`'s rows have no such neighbor, so
    /// they stay a plain rounded card). `nil` draws no tail. Ignored when
    /// `showsCardBackground` is `false`.
    var tailY: CGFloat?
    /// `false` for the flat "Co hrálo" home-screen list (2026-08-23
    /// redesign) — no card fill/border, rows just sit on the page
    /// background separated by a hairline (see `HistoryRowView`).
    /// `FavoritesView`'s free-floating cards keep the default `true`.
    var showsCardBackground = true
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
                artworkWithPreviewBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(artist)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
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
                    if let favorite {
                        ActionPillButton(
                            label: favorite.isFavorite ? L10n.favoriteRemoveAction : L10n.favoriteAddAction,
                            tint: Theme.gold,
                            action: favorite.action
                        )
                    }
                    if let spotifyURL {
                        ActionPillButton(label: L10n.spotifyFindAction, tint: Theme.spotifyGreen) {
                            openURL(spotifyURL)
                        }
                    }
                }
            }
        }
        .padding(showsCardBackground ? Theme.Spacing.md : 0)
        .modifier(CardBackgroundModifier(isEnabled: showsCardBackground, cornerRadius: Theme.Radius.card, tailY: tailY))
    }

    /// The artwork with a translucent play/pause badge centered over it
    /// when a preview is available — tapping the artwork itself to hear a
    /// clip, the way Spotify/Apple Music treat album art, rather than a
    /// separate "Přehrát ukázku" pill competing for attention below.
    @ViewBuilder
    private var artworkWithPreviewBadge: some View {
        if let preview {
            Button(action: preview.action) {
                artwork(size: 80)
                    .overlay {
                        previewBadge(preview.playback)
                    }
            }
            .buttonStyle(.plain)
            .disabled(preview.playback == .loading)
        } else {
            artwork(size: 80)
        }
    }

    private func previewBadge(_ playback: PreviewPlaybackState) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.5))
            Group {
                switch playback {
                case .idle:
                    Image(systemName: "play.fill")
                case .loading:
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.65)
                case .playing:
                    Image(systemName: "pause.fill")
                }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
    }

    private func artwork(size: CGFloat) -> some View {
        RemoteArtworkView(url: artworkURL, cornerRadius: cornerRadius)
            .frame(width: size, height: size)
            .id(artworkURL)
            .transition(.opacity)
    }
}

/// Applies `TrackDetailsRow`'s card fill/border when `isEnabled`, or does
/// nothing when the caller wants the flat "Co hrálo" list look instead
/// (see `showsCardBackground`).
private struct CardBackgroundModifier: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let tailY: CGFloat?

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .background(Theme.surface, in: CalloutCardShape(cornerRadius: cornerRadius, tailY: tailY))
                .overlay(
                    // `.allowsHitTesting(false)` is load-bearing: an
                    // overlaid Shape is hit-testable across its whole
                    // (geometric, not just drawn) area by default even when
                    // only stroked, which — sitting in front of the action
                    // pills below in z-order — silently swallowed every tap
                    // meant for them. Decorative-only border, so it must
                    // not intercept touches.
                    CalloutCardShape(cornerRadius: cornerRadius, tailY: tailY)
                        .stroke(Theme.hairline(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        } else {
            content
        }
    }
}

/// A rounded card, optionally with a small speech-bubble tail poking out of
/// the left edge — used to visually tie a "Co hrálo" card back to its
/// timestamp, which sits just to its left in `HistoryRowView`. With
/// `tailY == nil` this is just a plain rounded rectangle.
private struct CalloutCardShape: Shape {
    var cornerRadius: CGFloat
    var tailY: CGFloat?
    var tailReach: CGFloat = 7
    var tailSpan: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        guard let tailY else {
            return Path(roundedRect: rect, cornerRadius: cornerRadius)
        }

        let r = cornerRadius
        let tailTopY = tailY - tailSpan / 2
        let tailBottomY = tailY + tailSpan / 2

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: tailBottomY))
        path.addLine(to: CGPoint(x: rect.minX - tailReach, y: tailY))
        path.addLine(to: CGPoint(x: rect.minX, y: tailTopY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A labeled, filled-tint action chip — no icon, just text on a 10%-opacity
/// tint fill — used for the Spotify/favorite row below a `TrackDetailsRow`'s
/// expanded card. Matches the "Co hrálo" card redesign (2026-08-23),
/// replacing the earlier outlined capsule + icon.
private struct ActionPillButton: View {
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
                }
                Text(label)
                    .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
