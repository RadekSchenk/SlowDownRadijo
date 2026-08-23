import SwiftUI
import UIKit

/// Matches the Figma "radio-flat-typo" redesign (node 37:4): flat colors
/// (no gradients/glows/card surfaces), Manrope throughout, and a compact
/// timeline-style history list.
struct HomeView: View {
    @ObservedObject var nowPlaying: NowPlayingViewModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject private var favorites: FavoriteTrackStore

    /// One-shot: flips true the first time a favorite is ever added, so the
    /// explainer sheet below only appears once, ever.
    @AppStorage("hasSeenFavoritesIntro") private var hasSeenFavoritesIntro = false
    @State private var isShowingFavoritesIntro = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ZStack(alignment: .top) {
                    HomeHeroBackground(image: heroImage)
                        // Bleeds past the VStack's own 20pt horizontal
                        // inset (applied below) so the image reaches the
                        // true screen edges, while `AppHeaderView` stays
                        // inset like every other row.
                        .padding(.horizontal, -20)
                        .ignoresSafeArea(edges: .top)

                    AppHeaderView()
                }

                showInfoCard

                nowPlayingSection

                historySection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { history.loadIfNeeded() }
        .refreshable { history.refresh() }
        .onChange(of: favorites.favorites.count) { oldCount, newCount in
            guard newCount > oldCount, !hasSeenFavoritesIntro else { return }
            hasSeenFavoritesIntro = true
            isShowingFavoritesIntro = true
        }
        .sheet(isPresented: $isShowingFavoritesIntro) {
            FavoritesIntroView()
        }
    }

    /// The current show's artwork, unless it's "The Best of Slow Down" — a
    /// rotation filler block whose graphic is a generic branded card, not a
    /// real per-show photo, so the hero banner deliberately excludes it
    /// even though it does have an `imageURL` (still used for lock-screen
    /// art via `NowPlayingViewModel.publishNowPlaying`, where that's fine).
    private var heroImage: UIImage? {
        guard nowPlaying.currentShow?.name != "The Best of Slow Down" else { return nil }
        return nowPlaying.showArtwork
    }

    private var showInfoCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                OnAirBadge()
                Spacer(minLength: Theme.Spacing.sm)
                if let hostName = nowPlaying.currentShow?.hostName {
                    HostBadge(name: hostName, imageName: nowPlaying.currentShow?.hostImageName)
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                PlayButton(state: nowPlaying.playbackState, action: nowPlaying.togglePlayPause, diameter: 54, iconSize: 20)

                Text(nowPlaying.showName.uppercased())
                    .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }

            // Removed from the layout entirely while paused — not just
            // dimmed — matching the 2026-08-23 hero redesign.
            if nowPlaying.playbackState == .playing {
                NowPlayingWaveform(
                    progress: nowPlaying.showProgress,
                    trackID: nowPlaying.track?.displayText ?? nowPlaying.showName
                )
            }

            if let show = nowPlaying.currentShow {
                VStack(alignment: .leading, spacing: 10) {
                    ShowProgressBar(
                        show: show,
                        progress: nowPlaying.showProgress,
                        remainingMinutes: nowPlaying.showRemainingMinutes,
                        nextShow: nowPlaying.nextShow
                    )
                    SleepTimerButton(player: nowPlaying.player, currentShowEndDate: nowPlaying.currentShowEndDate)
                }
            }

            statusLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch nowPlaying.playbackState {
        case .error(let message):
            Text(message)
                .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                .foregroundStyle(Theme.statusError)
        case .connecting:
            Text(L10n.connecting)
                .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
        default:
            EmptyView()
        }
    }

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.nowPlayingHeading)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)

            nowPlayingRow
        }
    }

    /// Styled exactly like a "Co hrálo" row (see `TrackDetailsRow`) — only
    /// the leading slot differs: equalizer + "Nyní" stacked instead of a
    /// clock time, but at the same 44pt width as the history rows' time
    /// column so both lists line up. Note the bold/secondary lines are
    /// intentionally swapped from a history row: here the *artist* is the
    /// bold primary line and the track title is secondary, matching the
    /// Figma now-playing card (history rows do the opposite — title bold,
    /// artist secondary). Centered against the track row per the Figma spec.
    private var nowPlayingRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(spacing: 8) {
                NowPlayingEqualizer(isActive: nowPlaying.playbackState == .playing)
                Group {
                    if let trackStartedAt = nowPlaying.trackStartedAt {
                        Text(trackStartedAt, style: .time)
                    } else {
                        Text("--:--")
                    }
                }
                .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                .foregroundStyle(Theme.liveRed)
            }
            .frame(width: 44)

            TrackDetailsRow(
                artworkURL: nowPlaying.trackArtworkURL ?? nowPlaying.currentShow?.imageURL,
                title: primaryLine,
                artist: secondaryLine,
                spotifyURL: nowPlaying.track?.spotifySearchURL,
                cornerRadius: 12
            )
        }
    }

    /// Bold primary line — the artist, falling back to the show name when
    /// we don't have real track metadata yet.
    private var primaryLine: String {
        guard let artist = nowPlaying.track?.artist, !artist.isEmpty else {
            return nowPlaying.showName
        }
        return artist
    }

    private var secondaryLine: String {
        nowPlaying.track?.title ?? ""
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.coHralo)
                    .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.last24h)
                    .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            }

            switch history.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
            case .loaded(let tracks):
                if tracks.isEmpty {
                    Text(L10n.historyBuildingUp)
                        .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.lavender)
                } else {
                    // No inter-row spacing here — each row (HistoryRowView,
                    // ShowDividerRow) draws its own trailing hairline with
                    // top padding, so the divider sits flush against the
                    // row above rather than floating in extra gap space.
                    LazyVStack(spacing: 0) {
                        ForEach(Self.historyRows(from: tracks)) { row in
                            switch row {
                            case .track(let track):
                                HistoryRowView(track: track, isFresh: track.id == history.justInsertedTrackID)
                                    .onAppear { history.loadMoreIfNeeded(current: track) }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            case .divider(let show):
                                ShowDividerRow(show: show)
                                    .transition(.opacity)
                            }
                        }
                    }

                    if history.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                    } else if !history.hasMore {
                        Text(L10n.historyEnd)
                            .font(Theme.Typography.Manrope.regular(size: 11, relativeTo: .caption2))
                            .foregroundStyle(Theme.lavender)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
        }
    }

    /// A show-boundary divider is inserted right after the last (in time)
    /// track we have for a show, before the next, older show's tracks —
    /// e.g. "10:05 Midnight City" (last of Beat Brunch) is followed by a
    /// "09:00 · Beat Brunch s Jaro Cossiga" divider, then that show's
    /// earlier tracks. No divider before the very first row: the
    /// currently-airing show is already shown in `showInfoCard` above.
    private enum HistoryRow: Identifiable {
        case track(HistoryTrack)
        case divider(Show)

        var id: String {
            switch self {
            case .track(let track):
                return "track-\(track.id)"
            case .divider(let show):
                return "divider-\(show.id)-\(show.start)"
            }
        }
    }

    private static func historyRows(from tracks: [HistoryTrack]) -> [HistoryRow] {
        var rows: [HistoryRow] = []
        for (index, track) in tracks.enumerated() {
            rows.append(.track(track))

            let nextTrack = tracks[safe: index + 1]
            let showChanged = nextTrack?.show?.id != track.show?.id || nextTrack?.show?.start != track.show?.start
            if let show = track.show, nextTrack != nil, showChanged {
                rows.append(.divider(show))
            }
        }
        return rows
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
