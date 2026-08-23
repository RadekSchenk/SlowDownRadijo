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
    @EnvironmentObject private var previewPlayer: PreviewPlayerService

    /// One-shot: flips true the first time a favorite is ever added, so the
    /// explainer sheet below only appears once, ever.
    @AppStorage("hasSeenFavoritesIntro") private var hasSeenFavoritesIntro = false
    @State private var isShowingFavoritesIntro = false

    var body: some View {
        ScrollView {
            // Explicit per-section top padding instead of a uniform
            // `spacing:` — `remainingShowInfo` needs a tighter 20pt gap
            // after the hero (matching the Figma "variation-3-card" auto
            // layout's own internal gap, see `heroSection`), while the
            // later sections keep the wider 24pt gap.
            VStack(spacing: 0) {
                heroSection

                remainingShowInfo
                    .padding(.top, 20)

                nowPlayingSection
                    .padding(.top, Theme.Spacing.lg)

                historySection
                    .padding(.top, Theme.Spacing.lg)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        // Needs to live on the `ScrollView` itself, not a descendant — a
        // nested `.ignoresSafeArea(edges: .top)` inside a `ScrollView`
        // doesn't actually bleed past the status bar (the ScrollView still
        // insets its content by the safe area first), which is why the
        // hero previously left a gap above it instead of reaching the true
        // top edge like the Figma spec.
        .ignoresSafeArea(edges: .top)
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

    /// The current show's artwork — except "The Best of Slow Down", a
    /// rotation filler block whose own `imageURL` (still used as-is for
    /// lock-screen art via `NowPlayingViewModel.publishNowPlaying`) is a
    /// generic branded card, not a real per-show photo. For the in-app hero
    /// it uses a dedicated bundled photo (`TheBestOfSlowDownHero`) instead.
    private var heroImage: UIImage? {
        if nowPlaying.currentShow?.name == "The Best of Slow Down" {
            return UIImage(named: "TheBestOfSlowDownHero")
        }
        return nowPlaying.showArtwork
    }

    /// The hero image, header, on-air/host badges, and play button + show
    /// title all live in one `ZStack` — the image is a fixed-height band
    /// (`HomeHeroBackground.height`, 300pt as of 2026-08-23 — reaches
    /// roughly down to the waveform equalizer) starting at the very top of
    /// the screen, and the header plus the first two rows of show info are
    /// overlaid on top of it (the image's own bottom-edge gradient, in
    /// `HomeHeroBackground`, is what keeps that overlaid text legible).
    /// Everything else about the show (progress bar, sleep timer) sits
    /// below in normal flow — see `remainingShowInfo`.
    private var heroSection: some View {
        ZStack(alignment: .top) {
            HomeHeroBackground(image: heroImage)
                // Bleeds past the VStack's own 20pt horizontal inset
                // (applied at the top-level `body`) so the image reaches
                // the true screen edges, while everything overlaid on top
                // of it stays inset like every other row.
                .padding(.horizontal, -20)

            // Spacing 0 + explicit per-child top padding, not a uniform
            // `spacing:` — the header-to-badges gap (8) and the two
            // "variation-3-card" internal gaps (badges-to-title,
            // title-to-progress, both 20) are different Figma values, not
            // one shared number.
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView()
                    // The hero image itself bleeds all the way to the
                    // screen's true top edge, behind the status bar — but
                    // the header content shouldn't start until below it.
                    // Matches Figma's "app-header" frame, which sits at a
                    // fixed y=40 (its own status-bar mockup's height), not
                    // at y=0.
                    .padding(.top, 40)

                HStack(spacing: Theme.Spacing.sm) {
                    OnAirBadge()
                    Spacer(minLength: Theme.Spacing.sm)
                    if let hostName = nowPlaying.currentShow?.hostName {
                        HostBadge(name: hostName, imageName: nowPlaying.currentShow?.hostImageName)
                    }
                }
                .padding(.top, Theme.Spacing.sm)

                HStack(spacing: Theme.Spacing.md) {
                    PlayButton(state: nowPlaying.playbackState, action: nowPlaying.togglePlayPause, diameter: 54, iconSize: 20)

                    Text(nowPlaying.showName.uppercased())
                        .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                }
                .padding(.top, 20)
            }
        }
    }

    private var remainingShowInfo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let show = nowPlaying.currentShow {
                // 12pt matches the Figma "show-progress" container's own
                // gap for its three top-level children — the
                // waveform+track+labels group (inside ShowProgressBar),
                // the remaining-time block (also inside ShowProgressBar),
                // and this sleep-timer link.
                VStack(alignment: .leading, spacing: 12) {
                    ShowProgressBar(
                        show: show,
                        progress: nowPlaying.showProgress,
                        remainingMinutes: nowPlaying.showRemainingMinutes,
                        nextShow: nowPlaying.nextShow,
                        isPlaying: nowPlaying.playbackState == .playing,
                        waveformTrackID: nowPlaying.track?.displayText ?? nowPlaying.showName
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
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 8) {
                NowPlayingEqualizer(isActive: nowPlaying.playbackState == .playing)
                Group {
                    if let trackStartedAt = nowPlaying.trackStartedAt {
                        Text(trackStartedAt, style: .time)
                    } else {
                        Text("--:--")
                    }
                }
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.liveRed)
            }
            .frame(width: 44)

            TrackDetailsRow(
                artworkURL: nowPlaying.trackArtworkURL ?? nowPlaying.currentShow?.imageURL,
                title: primaryLine,
                artist: secondaryLine,
                spotifyURL: nowPlaying.track?.spotifySearchURL,
                cornerRadius: 2,
                preview: nowPlayingPreview
            )
        }
    }

    /// `nil` until we have a real track (artist + title) to preview —
    /// showing a play badge over placeholder/show artwork with nothing
    /// real to play would be broken, not just unhelpful.
    private var nowPlayingPreview: PreviewButtonState? {
        guard let track = nowPlaying.track, !track.artist.isEmpty, !track.title.isEmpty else { return nil }
        let key = FavoriteTrack.normalize(artist: track.artist, title: track.title)
        let playback: PreviewPlaybackState = previewPlayer.activeKey != key
            ? .idle
            : (previewPlayer.isLoading ? .loading : .playing)
        return PreviewButtonState(
            playback: playback,
            action: { previewPlayer.toggle(artist: track.artist, title: track.title) }
        )
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
                    .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .footnote))
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
