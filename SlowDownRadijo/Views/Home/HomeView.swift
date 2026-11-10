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
    /// How far the page is pulled down past its top (the rubber band);
    /// 0 otherwise. Grows the header's logo, card and title — the reverse
    /// of their fade on the way up.
    @State private var pullDistance: CGFloat = 0
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
                    .padding(.top, AppHeaderView.topInset)

                nowPlayingHeader

                // Figma's "scroll-content" wrapper spaces its top-level
                // sections (now-playing card, stats, Pořady) 32pt apart —
                // not the 24pt used between `HomeView`'s other sub-sections.
                if statsEnabled {
                    StatsHomeBlock(onOpen: onOpenStats)
                        .movesWithScroll()
                        .padding(.top, Theme.Spacing.xl)
                }

                if analytics.shouldAskForConsent {
                    AnalyticsConsentCard { granted in
                        withAnimation(Motion.cardResize) {
                            analytics.setConsent(granted)
                        }
                    }
                    .movesWithScroll()
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
            // Behind the header and the show, edge to edge, scrolling away
            // with them.
            .background(alignment: .top) {
                HeaderClouds(isPlaying: nowPlaying.playbackState == .playing)
            }
            .scrollsToTopOnTabReselect()
            // The content's top rests at the scroll view's top (the page
            // ignores the top safe area), so anything above 0 is pull.
            .onGeometryChange(for: CGFloat.self) { proxy in
                max(0, proxy.frame(in: .scrollView).minY)
            } action: { pull in
                pullDistance = pull
            }
        }
        // Like every other tab: the header starts `AppHeaderView.topInset`
        // below the true top edge (see `StatsView`).
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
        // A returning listener: the App Store's own rating dialog, once the
        // home screen has been up a moment (not over the launch cover, and
        // not on top of the analytics question).
        .task(id: reviewPrompt.shouldAsk && !analytics.shouldAskForConsent) {
            guard reviewPrompt.shouldAsk, !analytics.shouldAskForConsent else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, reviewPrompt.shouldAsk else { return }
            requestReview()
            reviewPrompt.didAsk()
        }
    }

    /// The current show's photo: bundled (`Show.artworkName`) where the
    /// show has one, else downloaded from `imageURL` — see
    /// `NowPlayingViewModel.loadShowArtwork`.
    private var heroImage: UIImage? {
        nowPlaying.showArtwork
    }

    /// Figma "Homepage — kompaktní seznam" (node 12390:245): the logo in
    /// the header between its pills, then the compact player — the cover
    /// with its equalizer next to the show title and host, the song below,
    /// then the programme progress and the player row. Behind the logo and
    /// the show, `HeaderClouds` drift while the radio plays. The section
    /// ends with the player row, then the 32pt gap to the stats.
    ///
    /// Scrolling away, each part fades and recedes towards its bottom edge
    /// as it passes under the top of the screen — the logo first, then the
    /// show — so each stays attached to what follows.
    private var nowPlayingHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Centred between the header's pills, hanging a little below
            // them, clear of the Dynamic Island; taps pass through to them.
            AnimatedBrandLogo()
                .frame(width: Self.logoSize.width, height: Self.logoSize.height)
                .allowsHitTesting(false)
                .growsOnPull(pullDistance, by: 0.15, anchor: .bottom)
                .frame(maxWidth: .infinity)
                .fadesOutUnderTopEdge(startingAt: Self.logoTop, shrinkingTo: 0.8)

            // Figma "Kompaktní přehrávač": 16pt between the show, the
            // song and the controls.
            showRow
                .growsOnPull(pullDistance, by: 0.04, anchor: .top)
                .fadesOutUnderTopEdge(shrinkingTo: 0.8)
                .padding(.top, 10)

            if let track = nowPlaying.verifiedTrack {
                SongHistoryLine(
                    current: track,
                    showStart: currentShowStart,
                    shows: scheduleStore.days.flatMap(\.shows),
                    showID: nowPlaying.currentShow?.id,
                    layout: .compact
                )
                .fadesOutUnderTopEdge()
                .padding(.top, 16)
                .transition(.reveal)
            }

            playerControls
                .padding(.top, 16)
        }
        .animation(Motion.cardResize, value: nowPlaying.verifiedTrack)
        // Figma "Značka a navigace" (89pt): the 66pt `AppHeaderView` bar,
        // and the logo 22pt below its top edge.
        .padding(.top, Self.logoTop - AppHeaderView.topInset - Self.headerHeight)
    }

    /// The header's height in Figma: 34pt pills and 16pt above and below.
    private static let headerHeight: CGFloat = 66
    /// Where the logo starts, from the top of the screen: 22pt below the
    /// 40pt status bar, so on an iPhone with a Dynamic Island (ending
    /// about 48pt down) it has room to breathe instead of touching it.
    private static let logoTop = AppHeaderView.topInset + 22
    private static let logoSize = CGSize(width: 80, height: 67)

    /// Figma "Pořad": the cover with its equalizer, 14pt, then the show's
    /// title and host.
    private var showRow: some View {
        HStack(spacing: 14) {
            NowPlayingCover(
                artwork: heroImage,
                isPlaying: nowPlaying.playbackState == .playing
            )

            VStack(alignment: .leading, spacing: 6) {
                // Here only, the show's own title without " s <host>"
                // ("Kurátorská selekce", not "… s Philip TBC") — the host
                // has its own line below. Everywhere else keeps the full
                // name.
                Text(nowPlaying.currentShow?.displayTitle ?? nowPlaying.showName)
                    .font(Theme.Typography.Heading.hero)
                    .foregroundStyle(Theme.textPrimary)
                    .manropeLineHeight(25.2, fontSize: 21)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                if let hostName = nowPlaying.currentShow?.hostName {
                    // Figma sets this line in Inter; the app uses Manrope
                    // throughout (see `Theme.Typography`).
                    Text("\(L10n.hostedByKicker) \(hostName)")
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The equalizer's outer bars sit on the page's content edge.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// When the show on air began — yesterday's date for one that started
    /// before midnight.
    private var currentShowStart: Date? {
        guard let show = nowPlaying.currentShow,
              let start = scheduleStore.startDate(for: show) else { return nil }
        return start > Date() ? start.addingTimeInterval(-24 * 3600) : start
    }

    /// "Listening controls": progress with times, then the player row.
    private var playerControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let show = nowPlaying.currentShow {
                ShowProgressBar(show: show, progress: nowPlaying.showProgress, isPlaying: nowPlaying.playbackState == .playing)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    if nowPlaying.currentShow != nil {
                        // Counts down by the minute (the sleep timer below
                        // it goes to the second), each changing digit
                        // popping in (library P9); tabular digits keep the
                        // width steady.
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            PopNumberText(
                                text: remainingLabel(now: context.date),
                                font: Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline).monospacedDigit(),
                                color: Theme.mutedText
                            )
                            .lineLimit(1)
                        }
                    }
                    SleepTimerButton(player: nowPlaying.player, currentShowEndDate: nowPlaying.currentShowEndDate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Where it plays, next to whether it plays: a quiet circle
                // the size of the play button, 16pt left of it.
                HStack(spacing: 16) {
                    OutputPickerButton(diameter: 46)
                    PlayButton(state: nowPlaying.playbackState, action: nowPlaying.togglePlayPause, diameter: 46, iconSize: 17)
                }
            }

            statusLabel
        }
    }

    private func remainingLabel(now: Date) -> String {
        guard let end = nowPlaying.currentShowEndDate else { return L10n.showEndingNow }
        let minutes = Int((end.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return L10n.showEndingNow }
        return L10n.showEndsIn(L10n.remaining(hours: minutes / 60, minutes: minutes % 60))
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
                .font(Theme.Typography.Heading.section)
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
                    .font(Theme.Typography.Heading.section)
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
