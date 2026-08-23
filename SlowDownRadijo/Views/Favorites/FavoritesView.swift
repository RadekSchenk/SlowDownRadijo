import SwiftUI

/// A primary tab (2026-08-23: promoted out of the hamburger menu into the
/// bottom tab bar) — every track the user has hearted from "Co hrálo",
/// styled like the home screen's history rows (see `TrackDetailsRow`),
/// with a trash button (confirmed via alert) to remove one.
struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoriteTrackStore
    @EnvironmentObject private var previewPlayer: PreviewPlayerService
    @State private var pendingDeletion: FavoriteTrack?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                AppHeaderView()
                    // Matches the home screen's header offset exactly (see
                    // `HomeView.heroSection`) — fixed 40pt from the true
                    // top edge, not the system safe-area inset, and the
                    // same 20pt horizontal inset as every other tab,
                    // independent of this screen's own 16pt content margin
                    // (applied to the inner VStack below, not shared with
                    // the header).
                    .padding(.top, 40)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(L10n.favoritesTitle)
                        .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                        .foregroundStyle(Theme.textPrimary)

                    if favorites.favorites.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(favorites.favorites, id: \.id) { favorite in
                                row(for: favorite)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.bottom, Theme.Spacing.md)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .alert(
            L10n.favoritesDeleteTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in if !isPresented { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { favorite in
            Button(L10n.favoritesDeleteCancel, role: .cancel) {}
            Button(L10n.favoritesDeleteConfirm, role: .destructive) {
                favorites.remove(favorite)
            }
        } message: { favorite in
            Text(L10n.favoritesDeleteMessage(trackTitle: favorite.title))
        }
    }

    private func row(for favorite: FavoriteTrack) -> some View {
        let playback = previewPlayback(for: favorite)
        return TrackDetailsRow(
            artworkURL: favorite.artworkURL,
            title: favorite.title,
            artist: favorite.artist,
            spotifyURL: spotifySearchURL(artist: favorite.artist, title: favorite.title),
            // 2pt matches the artwork radius used everywhere else (home
            // screen's "Co hrálo", Program's schedule rows) — was still the
            // default 8pt here, the one place that hadn't been unified yet.
            cornerRadius: 2,
            preview: PreviewButtonState(
                playback: playback,
                progress: playback == .playing ? previewPlayer.progress : 0,
                action: { previewPlayer.toggle(artist: favorite.artist, title: favorite.title) }
            )
        )
        .overlay(alignment: .topTrailing) {
            Button {
                pendingDeletion = favorite
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.statusError)
                    .frame(width: 30, height: 30)
                    .background(Theme.background, in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: -4, y: 4)
        }
    }

    private func previewPlayback(for favorite: FavoriteTrack) -> PreviewPlaybackState {
        let key = FavoriteTrack.normalize(artist: favorite.artist, title: favorite.title)
        guard previewPlayer.activeKey == key else { return .idle }
        return previewPlayer.isLoading ? .loading : .playing
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "heart")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.lavender)
            Text(L10n.favoritesEmptyTitle)
                .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.favoritesEmptyBody)
                .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }
}
