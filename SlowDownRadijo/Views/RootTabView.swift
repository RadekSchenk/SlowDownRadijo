import SwiftUI

struct RootTabView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @StateObject private var scheduleStore: ScheduleStore
    @StateObject private var player: RadioPlayerService
    @StateObject private var metadataService: ICYMetadataService

    @StateObject private var nowPlayingViewModel: NowPlayingViewModel
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var voiceMessageViewModel: VoiceMessageViewModel
    @StateObject private var favoriteTrackStore = FavoriteTrackStore()
    @StateObject private var previewPlayer: PreviewPlayerService
    @StateObject private var statsStore: ListeningStatsStore

    /// The Statistiky page's tab tag (0 radio, 1–2 feature-flagged, 3 Vzkaz,
    /// 4 Podpora).
    private static let statsTab = 5

    /// Figma's `bottom-nav` is 70pt tall; below it the design reserves a
    /// (hidden) 19pt strip for the home indicator. A real iPhone's bottom
    /// safe area is 34pt, which would leave the labels 44pt above the screen
    /// edge instead of the design's 29pt — see `bottomNav`.
    private static let homeIndicatorZone: CGFloat = 19

    @State private var selectedTab = 0
    /// The window's bottom safe-area inset (34pt on iPhones with a home
    /// indicator, 0 on those without), measured by `BottomSafeInsetKey`.
    @State private var bottomSafeInset: CGFloat = 0
    /// `init()` isn't a safe place for the autoplay side effect — SwiftUI
    /// re-invokes it (e.g. when `AppRootView` re-renders as the splash
    /// dismisses), which previously spun up a second `RadioPlayerService`
    /// and started a second, overlapping stream. `.onAppear` fires once for
    /// this view's actual lifetime in the hierarchy, and this flag guards
    /// against it firing more than once regardless.
    @State private var hasAutoplayed = false
    /// Toggle lives in `SettingsView` — off means the user has to tap Play
    /// themselves instead of the stream starting the instant the app opens.
    @AppStorage("autoplayEnabled") private var autoplayEnabled = true
    /// Guards the once-per-launch "Novinky" notification check the same
    /// way `hasAutoplayed` guards autoplay — see `NewsNotificationManager`.
    @State private var hasCheckedNewsNotifications = false

    init() {
        let schedule = ScheduleStore()
        let playerService = RadioPlayerService()
        let metadata = ICYMetadataService()
        let historyStore = PlayHistoryStore()

        _scheduleStore = StateObject(wrappedValue: schedule)
        _player = StateObject(wrappedValue: playerService)
        _metadataService = StateObject(wrappedValue: metadata)
        _nowPlayingViewModel = StateObject(wrappedValue: NowPlayingViewModel(
            player: playerService,
            metadataService: metadata,
            scheduleStore: schedule,
            historyStore: historyStore
        ))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel(historyStore: historyStore))
        _voiceMessageViewModel = StateObject(wrappedValue: VoiceMessageViewModel(radioPlayer: playerService))
        _previewPlayer = StateObject(wrappedValue: PreviewPlayerService(radioPlayer: playerService))
        _statsStore = StateObject(wrappedValue: ListeningStatsStore(scheduleStore: schedule))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    nowPlaying: nowPlayingViewModel,
                    history: historyViewModel,
                    scheduleStore: scheduleStore,
                    onOpenStats: { selectedTab = Self.statsTab }
                )
                .toolbar(.hidden, for: .navigationBar)
            }
            .tag(0)

            if FeatureFlags.standaloneProgramTab {
                NavigationStack {
                    ProgramView(scheduleStore: scheduleStore)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .tag(1)
            }

            if FeatureFlags.nowPlayingHistoryAndFavorites {
                NavigationStack {
                    FavoritesView()
                        .toolbar(.hidden, for: .navigationBar)
                }
                .tag(2)
            }

            NavigationStack {
                MessageView(viewModel: voiceMessageViewModel) {
                    selectedTab = 0
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tag(3)

            NavigationStack {
                SupportView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tag(4)

            NavigationStack {
                StatsView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tag(Self.statsTab)
        }
        // The native tab bar centers/compresses its items instead of
        // spreading them to Figma's `bottom-nav` spec (node 12294:257) —
        // 60pt side margins, space-between across the full width — so it
        // stays hidden and `bottomNav` below takes its place.
        .toolbar(.hidden, for: .tabBar)
        .tint(Theme.liveRed)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNav
        }
        // Read the inset from *outside* the inset above, where it still is the
        // window's own safe area.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: BottomSafeInsetKey.self, value: proxy.safeAreaInsets.bottom)
            }
            .ignoresSafeArea()
        }
        .onPreferenceChange(BottomSafeInsetKey.self) { bottomSafeInset = $0 }
        .environmentObject(favoriteTrackStore)
        .environmentObject(previewPlayer)
        .environmentObject(statsStore)
        .onAppear {
            configureNavigationBarAppearance()
            // Autoplay: a radio app should start making sound as soon as it
            // opens, not wait for a tap — unless the user turned it off.
            if !hasAutoplayed {
                hasAutoplayed = true
                if autoplayEnabled {
                    player.play()
                }
            }
            if !hasCheckedNewsNotifications {
                hasCheckedNewsNotifications = true
                Task { await NewsNotificationManager.checkForNewPost() }
            }
        }
    }

    /// Hand-built replacement for `TabView`'s own tab bar chrome — see the
    /// `.toolbar(.hidden, for: .tabBar)` comment above for why. Visible
    /// tabs are hardcoded (not derived from the `TabView` content above):
    /// Rádio, Vzkaz, Statistiky, Podpora. The two feature-flagged pages are
    /// kept out of the nav entirely, not just hidden from this bar.
    private var bottomNav: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.hairline(0.08))
                .frame(height: 1)

            HStack {
                tabBarButton(tag: 0, title: L10n.tabRadio, image: "TabIconRadio")
                Spacer(minLength: 0)
                tabBarButton(tag: 3, title: L10n.tabMessage, image: "TabIconMessage")
                Spacer(minLength: 0)
                tabBarButton(tag: Self.statsTab, title: L10n.tabStats, image: "TabIconStats")
                Spacer(minLength: 0)
                tabBarButton(tag: 4, title: L10n.tabSupport, image: "TabIconSupport")
            }
            // Figma `bottom-nav` (node 12294:257), measured from the render:
            // the bar has 16pt side padding and the tab row another 24pt, so
            // the tabs sit 40pt from each edge with `space-between` across
            // the rest (≈44pt gaps for four tabs). Tab row: 14pt from the
            // frame top (1pt hairline + 13), 10pt below → 70pt in total.
            .padding(.horizontal, 40)
            .padding(.top, 13)
            .padding(.bottom, 10)
        }
        // Trim the real safe area (34pt) down to the design's 19pt
        // home-indicator strip: the negative padding lets the bar's bottom edge
        // reach into the safe area, the background below fills the rest.
        .padding(.bottom, bottomSafeInset > 0 ? Self.homeIndicatorZone - bottomSafeInset : 0)
        .background(Theme.tabBarBackground.ignoresSafeArea(edges: .bottom))
    }

    private func tabBarButton(tag: Int, title: String, image: String) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 6) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 12))
                    .frame(height: 16)
            }
            .foregroundStyle(isSelected ? Theme.liveRed : Theme.tabBarUnselected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func configureNavigationBarAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Theme.background)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: Theme.Typography.Manrope.uiFont(weight: "Bold", size: 17)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: Theme.Typography.Manrope.uiFont(weight: "ExtraBold", size: 34)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

/// The window's bottom safe-area inset, reported from a background that
/// ignores the safe area (see `RootTabView.body`).
private struct BottomSafeInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
