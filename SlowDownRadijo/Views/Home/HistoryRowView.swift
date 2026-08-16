import SwiftUI

/// A single "Co hrálo" timeline row: play time in its own leading column,
/// then `TrackDetailsRow`. Matches the flat Figma redesign's
/// "timeline-row" layout.
struct HistoryRowView: View {
    let track: HistoryTrack
    /// True for a brief moment right after this row lands here from "Nyní
    /// hraje" — draws a soft highlight that fades out, so the arrival reads
    /// as "this just fell from Now Playing" rather than silently appearing.
    var isFresh: Bool = false

    @EnvironmentObject private var favorites: FavoriteTrackStore
    @EnvironmentObject private var previewPlayer: PreviewPlayerService

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Group {
                if let playedAt = track.playedAt {
                    Text(playedAt, style: .time)
                } else {
                    Text("--:--")
                }
            }
            .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .footnote))
            .foregroundStyle(Theme.lavender)
            .frame(width: 44, height: 64, alignment: .center)

            TrackDetailsRow(
                artworkURL: track.artworkURL,
                title: track.title,
                artist: track.artist,
                spotifyURL: track.spotifySearchURL,
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
    }

    private var previewPlayback: PreviewPlaybackState {
        let key = FavoriteTrack.normalize(artist: track.artist, title: track.title)
        guard previewPlayer.activeKey == key else { return .idle }
        return previewPlayer.isLoading ? .loading : .playing
    }
}
