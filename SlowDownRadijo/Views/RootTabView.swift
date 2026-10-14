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

    /// The window's bottom safe-area inset: 34pt on iPhones with a home
    /// indicator, 0 on those without. Read from UIKit — a `GeometryReader`
    /// inside the `safeAreaInset` / an ignoring background reports 0 here.
    /// `body` re-runs right after the first `.onAppear` (state changes), by
    /// which time the window exists.
    private var bottomSafeInset: CGFloat {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.bottom ?? 0
    }

    @State private var selectedTab = 0
    /// Pages built so far (see `tabPage`).
    @State private var visitedTabs: Set<Int> = [0]
    /// Taps on the already selected tab, per tab: each one scrolls that
    /// page back to the top (`.scrollsToTopOnTabReselect()`).
    @State private var reselectCounts: [Int: Int] = [:]
    #if DEBUG
    /// Tab-bar taps, for the UI tests' diagnostics.
    @State private var debugTabTaps = 0
    @State private var debugBarTouches = 0
    @State private var debugHitInfo = "not probed"
    #endif
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
    /// The last notification tap acted on (see `ShowReminderStore.OpenRequest`).
    @State private var handledOpenRequestID: UUID?

    /// The services the state objects share, built on first access only.
    /// SwiftUI may call `init()` again, but it evaluates each `StateObject`
    /// autoclosure just once — so nothing is constructed eagerly here (a
    /// stray `RadioPlayerService` re-activated the audio session and added
    /// remote-command targets; a stray `ICYMetadataService` was never freed).
    @MainActor
    private final class SharedServices {
        lazy var schedule = ScheduleStore()
        lazy var player = RadioPlayerService()
        lazy var metadata = ICYMetadataService()
        lazy var historyStore = PlayHistoryStore()
    }

    init() {
        let services = SharedServices()

        _scheduleStore = StateObject(wrappedValue: services.schedule)
        _player = StateObject(wrappedValue: services.player)
        _metadataService = StateObject(wrappedValue: services.metadata)
        _nowPlayingViewModel = StateObject(wrappedValue: NowPlayingViewModel(
            player: services.player,
            metadataService: services.metadata,
            scheduleStore: services.schedule,
            historyStore: services.historyStore
        ))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel(historyStore: services.historyStore))
        _voiceMessageViewModel = StateObject(wrappedValue: VoiceMessageViewModel(radioPlayer: services.player))
        _previewPlayer = StateObject(wrappedValue: PreviewPlayerService(radioPlayer: services.player))
        _statsStore = StateObject(wrappedValue: ListeningStatsStore(scheduleStore: services.schedule))
    }

    var body: some View {
        // Our own tab container instead of `TabView`: the bottom bar is
        // hand-built (Figma `bottom-nav`), and on iOS 26 a hidden system tab
        // bar under it kept the highlight stuck on Rádio. Each page is built
        // on its first visit and then kept alive (scroll position, state),
        // only the selected one is shown.
        //
        // The pages and the bar are stacked, not overlapped: nothing of a
        // page may reach under the bar, or it takes the bar's taps.
        VStack(spacing: 0) {
            pages
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toastOverlay()

            bottomNav
        }
        // The bar reaches the screen's bottom edge itself (see `bottomNav`).
        .ignoresSafeArea(.container, edges: .bottom)
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel(debugHitInfo)
                .accessibilityValue("barTouches=\(debugBarTouches)")
                .accessibilityIdentifier("debug.hit")
        }
        .task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(2))
                probeHits()
            }
        }
        #endif
        .tint(Theme.liveRed)
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
                    player.play(trigger: .autoplay)
                }
            }
            if !hasCheckedNewsNotifications {
                hasCheckedNewsNotifications = true
                Task { await NewsNotificationManager.checkForNewPost() }
            }
            ShowReminderStore.shared.reschedule()
            Analytics.shared.screen(.home)
        }
        // A tap on a "Právě začíná" notification: home, and the radio for
        // "Poslouchat".
        .onReceive(ShowReminderStore.shared.$openRequest.compactMap { $0 }) { request in
            ShowReminderStore.shared.finishOpenRequest(request)
            guard request.id != handledOpenRequestID else { return }
            handledOpenRequestID = request.id
            selectedTab = 0
            Analytics.shared.track(.showNotificationOpened(showID: request.showID, listen: request.listen))
            if request.listen, player.state != .playing {
                player.play(trigger: .notification)
            }
        }
        .onChange(of: selectedTab) { old, tab in
            #if DEBUG
            print("[tabbar] selectedTab \(old) -> \(tab)")
            #endif
            let isFirstVisit = visitedTabs.insert(tab).inserted
            Analytics.shared.screen(Self.analyticsScreen(for: tab))
            if tab == Self.statsTab {
                Analytics.shared.track(.statsOpened(communityUnlocked: statsStore.communityUnlocked))
                // The page refreshes itself when first built; it then stays
                // alive, so later visits refresh from here.
                if !isFirstVisit {
                    Task { await statsStore.refreshAll() }
                }
            }
        }
    }

    /// The tab pages, one above the other; see `tabPage`.
    private var pages: some View {
        ZStack {
            tabPage(0) {
                HomeView(
                    nowPlaying: nowPlayingViewModel,
                    history: historyViewModel,
                    scheduleStore: scheduleStore,
                    onOpenStats: { selectedTab = Self.statsTab }
                )
            }

            if FeatureFlags.standaloneProgramTab {
                tabPage(1) { ProgramView(scheduleStore: scheduleStore) }
            }

            if FeatureFlags.nowPlayingHistoryAndFavorites {
                tabPage(2) { FavoritesView() }
            }

            tabPage(3) {
                MessageView(viewModel: voiceMessageViewModel) {
                    selectedTab = 0
                }
            }

            tabPage(4) { SupportView() }

            tabPage(Self.statsTab) { StatsView() }
        }
    }

    /// One page of the tab container: built on its first visit, then kept
    /// in the hierarchy and only shown while selected.
    @ViewBuilder
    private func tabPage<Content: View>(_ tag: Int, @ViewBuilder content: () -> Content) -> some View {
        if visitedTabs.contains(tag) || selectedTab == tag {
            let isSelected = selectedTab == tag
            // No `NavigationStack`: the pages push nothing (the menu has its
            // own), and a UIKit navigation view only adds a layer that can
            // catch touches.
            content()
                .environment(\.tabReselectCount, reselectCounts[tag, default: 0])
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .accessibilityHidden(!isSelected)
                .zIndex(isSelected ? 1 : 0)
                #if DEBUG
                // Lets the UI tests see which page is on screen.
                .overlay(alignment: .topLeading) {
                    if isSelected {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityLabel("page \(tag)")
                            .accessibilityIdentifier("page.\(tag)")
                    }
                }
                #endif
        }
    }

    /// The hand-built tab bar (Figma `bottom-nav`, node 12294:257: 40pt
    /// side insets, tabs spread across the width). Visible tabs are
    /// hardcoded (not derived from the pages above):
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
            // the rest (≈44pt gaps for four tabs). Tab row: 14pt padding above
            // (below the 1pt hairline) and 10pt below the icons and labels.
            .padding(.horizontal, 40)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        // The bar runs to the screen's bottom edge (`body` ignores the bottom
        // safe area); below the tabs it keeps the design's 19pt home-indicator
        // strip instead of the real 34pt safe area.
        .padding(.bottom, bottomSafeInset > 0 ? Self.homeIndicatorZone : 0)
        .background(Theme.tabBarBackground)
        #if DEBUG
        .simultaneousGesture(TapGesture().onEnded { debugBarTouches += 1 })
        #endif
    }

    #if DEBUG
    /// Which UIKit view would get a touch on the tab bar, and on the page —
    /// for the UI tests' diagnostics.
    private func probeHits() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        let windowList = windows.map { "\(type(of: $0))(level \($0.windowLevel.rawValue), hidden \($0.isHidden), key \($0.isKeyWindow), \($0.frame.integral))" }
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else {
            debugHitInfo = "no window"
            return
        }
        let height = window.bounds.height
        let points: [(String, CGPoint)] = [("bar", CGPoint(x: 151, y: height - 52)), ("page", CGPoint(x: 200, y: 300))]
        let hits = points.map { name, point -> String in
            var chain: [String] = []
            var view = window.hitTest(point, with: nil)
            while let current = view, chain.count < 8 {
                chain.append("\(type(of: current))\(current.frame.integral)")
                view = current.superview
            }
            return "\(name)@\(Int(point.y)): " + chain.joined(separator: " < ")
        }
        debugHitInfo = "windows: " + windowList.joined(separator: "; ") + " || " + hits.joined(separator: " || ")
    }
    #endif

    private static func analyticsScreen(for tab: Int) -> AnalyticsScreen {
        switch tab {
        case 3: return .message
        case 4: return .support
        case statsTab: return .stats
        default: return .home
        }
    }

    private func tabBarButton(tag: Int, title: String, image: String) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            #if DEBUG
            debugTabTaps += 1
            print("[tabbar] tap tag=\(tag) selected=\(selectedTab) taps=\(debugTabTaps)")
            #endif
            if isSelected {
                reselectCounts[tag, default: 0] += 1
            } else {
                selectedTab = tag
            }
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
            // The whole tab is tappable, not just the icon and label glyphs.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab.\(tag)")
        #if DEBUG
        .accessibilityValue("selected=\(selectedTab) taps=\(debugTabTaps)")
        #endif
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
