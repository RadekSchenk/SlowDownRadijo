import SwiftUI

@main
struct SlowDownRadijoApp: App {
    init() {
        NewsNotificationManager.configureForegroundPresentation()
        ShowReminderStore.registerNotificationCategory()
        Analytics.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task {
                    AccountService.shared.start()
                    ChatService.shared.start()
                }
                // Google's sign-in sheet returns through its URL scheme.
                .onOpenURL { url in
                    if ChatService.shared.handleInvite(url) { return }
                    AccountService.handle(url)
                }
                // A DJ invite opened as a universal link.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { _ = ChatService.shared.handleInvite(url) }
                }
        }
    }
}

/// Covers the first moments after launch with `SplashScreenView` — an exact
/// copy of the system launch screen, so the two read as one — then fades
/// it out as soon as the tab interface has drawn its first frame. The tab
/// view is mounted from the start, so its services warm up underneath.
private struct AppRootView: View {
    @State private var showSplash = true
    /// Once a day in the winter season (`WinterSeason.takeSplash`).
    @State private var winterSplash = WinterSeason.takeSplash()
    private let christmas = WinterSeason.isChristmasNow()

    /// Just long enough for the home screen to lay out under the cover;
    /// the app itself is ready by then (the schedule ships in the bundle,
    /// and the slower start-up work waits until after it — see
    /// `RootTabView`'s autoplay and `PlayHistoryStore`).
    private static let hold: Duration = .milliseconds(80)
    /// The winter splash stays long enough to be seen: its picture comes in
    /// over `SplashScreenView.reveal`, then rests a moment (the wish a
    /// little longer). The radio's autoplay starts underneath meanwhile.
    private static let winterHold: Duration = .milliseconds(1500)
    private static let christmasHold: Duration = .milliseconds(2100)

    var body: some View {
        ZStack {
            RootTabView()

            if showSplash {
                SplashScreenView(winter: winterSplash, christmas: winterSplash && christmas)
                    .transition(.opacity)
            }
        }
        // Dark only: no light mode, no appearance toggle.
        .preferredColorScheme(.dark)
        .appTextSizeLimit()
        .task {
            let hold = !winterSplash ? Self.hold : christmas ? Self.christmasHold : Self.winterHold
            try? await Task.sleep(for: hold)
            withAnimation(.easeOut(duration: winterSplash ? 0.35 : 0.2)) {
                showSplash = false
            }
        }
    }
}
