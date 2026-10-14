import StoreKit
import SwiftUI
import UIKit

/// Matches the Figma "radio-flat-typo" redesign (node 37:4): flat colors
/// (no gradients/glows/card surfaces), Manrope throughout, and a compact
/// timeline-style history list.
struct HomeView: View {
    @ObservedObject var nowPlaying: NowPlayingViewModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var loc = LocalizationManager.shared
    @EnvironmentObject private var favorites: FavoriteTrackStore
    @EnvironmentObject private var previewPlayer: PreviewPlayerService
    @Environment(\.openURL) private var openURL
    @ObservedObject private var analytics = Analytics.shared
    @ObservedObject private var reviewPrompt = ReviewPrompt.shared
    @Environment(\.requestReview) private var requestReview
    @State private var isShowingFeedback = false
    @AppStorage(StatsConfig.enabledKey) private var statsEnabled = true
    /// Tapping the stats block jumps to the Statistiky tab.
    var onOpenStats: () -> Void = {}

    /// One-shot: flips true the first time a favorite is ever added, so the
    /// explainer sheet below only appears once, ever.
    @AppStorage("hasSeenFavoritesIntro") private var hasSeenFavoritesIntro = false
    @State private var isShowingFavoritesIntro = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppHeaderView()
                    .padding(.top, 40)

                nowPlayingHeader

                // Figma's "scroll-content" wrapper spaces its top-level
                // sections (now-playing card, stats, Pořady) 32pt apart —
                // not the 24pt used between `HomeView`'s other sub-sections.
                if statsEnabled {
                    StatsHomeBlock(onOpen: onOpenStats)
                        .padding(.top, Theme.Spacing.xl)
                }

                if analytics.shouldAskForConsent {
                    AnalyticsConsentCard { granted in
                        withAnimation(Motion.cardResize) {
                            analytics.setConsent(granted)
                        }
                    }
                    .padding(.top, Theme.Spacing.xl)
                    .transition(.reveal)
                } else if reviewPrompt.shouldAsk {
                    // Liked → the App Store's own rating dialog (iOS decides
                    // whether it appears); not → the feedback form.
                    ReviewPromptCard { liked in
                        withAnimation(Motion.cardResize) {
                            reviewPrompt.answered(liked: liked)
                        }
                        if liked {
                            requestReview()
                        } else {
                            isShowingFeedback = true
                        }
                    }
                    .padding(.top, Theme.Spacing.xl)
                    .transition(.reveal)
                }

                HomeProgramSection(scheduleStore: scheduleStore, currentShow: nowPlaying.currentShow)
                    .padding(.top, Theme.Spacing.xl)

                if FeatureFlags.nowPlayingHistoryAndFavorites {
                    nowPlayingSection
                        .padding(.top, Theme.Spacing.lg)

                    historySection
                        .padding(.top, Theme.Spacing.lg)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
            .coordinateSpace(.named(NowPlayingCard.scrollContentSpace))
            .scrollsToTopOnTabReselect()
        }
        // Like every other tab: the header starts 40pt below the true top
        // edge (see `StatsView`).
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            if FeatureFlags.nowPlayingHistoryAndFavorites { history.loadIfNeeded() }
        }
        .refreshable {
            if FeatureFlags.nowPlayingHistoryAndFavorites { history.refresh() }
        }
        .onChange(of: favorites.favorites.count) { oldCount, newCount in
            guard FeatureFlags.nowPlayingHistoryAndFavorites, newCount > oldCount, !hasSeenFavoritesIntro else { return }
            hasSeenFavoritesIntro = true
            isShowingFavoritesIntro = true
        }
        .sheet(isPresented: $isShowingFavoritesIntro) {
            FavoritesIntroView()
                .appTextSizeLimit()
        }
        // "Not really" on the review card: straight to the feedback form.
        .sheet(isPresented: $isShowingFeedback) {
            NavigationStack {
                FeedbackView()
            }
            .appTextSizeLimit()
        }
    }

    /// The current show's photo: bundled (`Show.artworkName`) where the
    /// show has one, else downloaded from `imageURL` — see
    /// `NowPlayingViewModel.loadShowArtwork`.
    private var heroImage: UIImage? {
        nowPlaying.showArtwork
    }

    /// Figma "variation-3-card" (node 12318:5166): the show card with its
    /// equalizer, then the ON-AIR badge, title and host (centred), the
    /// programme progress and the player row — the remaining time and
    /// sleep timer on the left, the play button on the right.
    private var nowPlayingHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            NowPlayingCard(
                artwork: heroImage,
                isPlaying: nowPlaying.playbackState == .playing
            )
            .collapsesOnScroll()

            // Card, "Player details" title block and controls: all 16pt apart.
            showTitle

            playerControls
        }
        // Figma: 16pt above the card; the section (458pt) ends with the
        // player row, then the 32pt gap to the stats.
        .padding(.top, 16)
    }

    private var showTitle: some View {
        VStack(spacing: 8) {
            OnAirBadge()

            // Here only, the show's own title without " s <host>" ("Kurátorská
            // selekce", not "… s Philip TBC") — the host has its own line
            // below. Everywhere else keeps the full name.
            Text(nowPlaying.currentShow?.displayTitle ?? nowPlaying.showName)
                .font(Theme.Typography.Manrope.extraBold(size: 20, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .manropeLineHeight(24, fontSize: 20)

            if let hostName = nowPlaying.currentShow?.hostName {
                // Figma sets this line in Inter; the app uses Manrope
                // throughout (see `Theme.Typography`). The divider under it
                // is exactly as wide as this line: it's drawn in the text's
                // own bounds, 8pt below it. (Not `fixedSize`, which kept a
                // long line from wrapping at large text sizes and pushed the
                // page wider than the screen.)
                let showsDivider = nowPlaying.verifiedTrack != nil
                Text("\(L10n.hostedByKicker) \(hostName)")
                    .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .manropeLineHeight(16.8, fontSize: 12)
                    .padding(.bottom, showsDivider ? 9 : 0)
                    .overlay(alignment: .bottom) {
                        if showsDivider {
                            Rectangle()
                                .fill(Theme.divider)
                                .frame(height: 1)
                                .transition(.opacity)
                        }
                    }
            } else if nowPlaying.verifiedTrack != nil {
                // No host line to measure: Figma's own 110pt.
                Rectangle()
                    .fill(Theme.divider)
                    .frame(width: 110, height: 1)
                    .transition(.opacity)
            }

            if let track = nowPlaying.verifiedTrack {
                nowPlayingTrackLink(track)
                    .transition(.reveal)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(Motion.cardResize, value: nowPlaying.verifiedTrack)
    }

    /// The song playing now (only when `TrackTrust` vouches for it):
    /// "Artist – Title" in white with the green Spotify mark; text and
    /// mark both open a Spotify search for artist + title.
    private func nowPlayingTrackLink(_ track: NowPlayingTrack) -> some View {
        Button {
            if let url = track.spotifySearchURL {
                Analytics.shared.track(.spotifyOpened(showID: nowPlaying.currentShow?.id))
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(track.artist) – \(track.title)")
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .manropeLineHeight(19.6, fontSize: 14)
                    .contentTransition(.opacity)

                Image("SpotifyIcon")
                    .resizable()
                    .frame(width: 19, height: 19.623)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.artist) – \(track.title)")
        .accessibilityHint(L10n.spotifyFindAction)
    }

    /// "Listening controls": progress with times, then the player row.
    private var playerControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let show = nowPlaying.currentShow {
                ShowProgressBar(show: show, progress: nowPlaying.showProgress)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    if nowPlaying.currentShow != nil {
                        // The minutes count down with the number pop-in
                        // (library P9).
                        PopNumberText(
                            text: remainingLabel,
                            font: Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline),
                            color: Theme.mutedText
                        )
                        .lineLimit(1)
                    }
                    SleepTimerButton(player: nowPlaying.player, currentShowEndDate: nowPlaying.currentShowEndDate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PlayButton(state: nowPlaying.playbackState, action: nowPlaying.togglePlayPause, diameter: 46, iconSize: 17)
            }

            statusLabel
        }
    }

    private var remainingLabel: String {
        let minutes = nowPlaying.showRemainingMinutes
        guard minutes > 0 else { return L10n.showEndingNow }
        guard minutes >= 60 else { return L10n.showEndsIn(L10n.minutesShort(minutes)) }
        return L10n.showEndsIn(L10n.durationShort(hours: minutes / 60, minutes: minutes % 60))
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch nowPlaying.playbackState {
        case .error(let message):
            Text(message)
                .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                .foregroundStyle(Theme.statusError)
        case .connecting:
            ShimmerText(
                text: L10n.connecting,
                font: Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote),
                base: Theme.lavender
            )
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
    /// column so both lists line up. Bold/secondary lines match every
    /// history row: title bold/primary, artist secondary underneath.
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

    /// `nil` until we have a real track (artist + title) to preview, or if
    /// iTunes has confirmed this one has no match (a jingle, station ID, DJ
    /// mix block) — showing a play badge with nothing real to play would be
    /// broken, not just unhelpful.
    private var nowPlayingPreview: PreviewButtonState? {
        guard let track = nowPlaying.track, !track.artist.isEmpty, !track.title.isEmpty,
              !nowPlaying.currentTrackHasNoITunesMatch else { return nil }
        let key = FavoriteTrack.normalize(artist: track.artist, title: track.title)
        let playback: PreviewPlaybackState = previewPlayer.activeKey != key
            ? .idle
            : (previewPlayer.isLoading ? .loading : .playing)
        return PreviewButtonState(
            playback: playback,
            progress: playback == .playing ? previewPlayer.progress : 0,
            action: { previewPlayer.toggle(artist: track.artist, title: track.title) }
        )
    }

    /// Bold primary line — the track title, falling back to the show name
    /// when we don't have real track metadata yet.
    private var primaryLine: String {
        guard let title = nowPlaying.track?.title, !title.isEmpty else {
            return nowPlaying.showName
        }
        return title
    }

    private var secondaryLine: String {
        nowPlaying.track?.artist ?? ""
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
