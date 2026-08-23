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

    @State private var selectedTab = 0
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
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(nowPlaying: nowPlayingViewModel, history: historyViewModel)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label(L10n.tabRadio, systemImage: "antenna.radiowaves.left.and.right") }
            .tag(0)

            NavigationStack {
                ProgramView(scheduleStore: scheduleStore)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label(L10n.tabProgram, systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                MessageView(viewModel: voiceMessageViewModel) {
                    selectedTab = 0
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label(L10n.tabMessage, systemImage: "message.circle") }
            .tag(2)

            NavigationStack {
                SupportView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label(L10n.tabSupport, systemImage: "heart") }
            .tag(3)
        }
        .tint(Theme.sunOrange)
        .environmentObject(favoriteTrackStore)
        .environmentObject(previewPlayer)
        .onAppear {
            configureTabBarAppearance()
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

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.tabBarBackground)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        // Tab item labels otherwise fall back to the system font — the one
        // piece of chrome on every screen that isn't SwiftUI `Text`, so it
        // was missing Manrope entirely until this was added.
        let tabFont = Theme.Typography.Manrope.uiFont(weight: "SemiBold", size: 11)
        let unselected: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(Theme.tabBarUnselected),
            .font: tabFont
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = unselected
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.tabBarUnselected)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.font: tabFont]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        // Belt-and-suspenders: newer iOS tab bar rendering doesn't always
        // honor `stackedLayoutAppearance.normal` for unselected items, but
        // this older, coarser property is still respected.
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.tabBarUnselected)

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
