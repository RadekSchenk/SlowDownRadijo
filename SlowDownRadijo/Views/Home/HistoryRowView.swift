import SwiftUI

/// A single "Co hrálo" timeline row: play time in its own leading column,
/// then `TrackDetailsRow`, then a trailing hairline. Flat — no per-row card
/// fill/border — matching the 2026-08-23 "Co hrálo" card redesign; rows
/// sit directly on `Theme.background`, separated only by the hairline.
struct HistoryRowView: View {
    let track: HistoryTrack
    /// True for a brief moment right after this row lands here from "Nyní
    /// hraje" — draws a soft highlight that fades out, so the arrival reads
    /// as "this just fell from Now Playing" rather than silently appearing.
    var isFresh: Bool = false

    @EnvironmentObject private var favorites: FavoriteTrackStore
    @EnvironmentObject private var previewPlayer: PreviewPlayerService

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let playedAt = track.playedAt {
                        Text(playedAt, style: .time)
                    } else {
                        Text("--:--")
                    }
                }
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
                .frame(width: 44, height: 80, alignment: .center)

                TrackDetailsRow(
                    artworkURL: track.artworkURL,
                    title: track.title,
                    artist: track.artist,
                    spotifyURL: track.spotifySearchURL,
                    cornerRadius: 2,
                    hasNoITunesMatch: track.hasNoITunesMatch,
                    showsCardBackground: false,
                    favorite: FavoriteButtonState(
                        isFavorite: favorites.isFavorite(artist: track.artist, title: track.title),
                        action: {
                            favorites.toggle(artist: track.artist, title: track.title, artworkURL: track.artworkURL)
                        }
                    ),
                    preview: PreviewButtonState(
                        playback: previewPlayback,
                        action: { previewPlayer.toggle(artist: track.artist, title: track.title) }
                    )
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.sunOrange.opacity(isFresh ? 0.14 : 0))
                    .padding(.vertical, -6)
                    .padding(.horizontal, -8)
            )

            // 12pt matches the Figma redesign's row gap exactly — applied
            // on both sides of the hairline (not just above it) so the
            // line sits centered in the gap between this row and the next,
            // rather than hugging one of them.
            Rectangle()
                .fill(Theme.hairline(0.12))
                .frame(height: 1)
                .padding(.vertical, 12)
        }
    }

    private var previewPlayback: PreviewPlaybackState {
        let key = FavoriteTrack.normalize(artist: track.artist, title: track.title)
        guard previewPlayer.activeKey == key else { return .idle }
        return previewPlayer.isLoading ? .loading : .playing
    }
}
