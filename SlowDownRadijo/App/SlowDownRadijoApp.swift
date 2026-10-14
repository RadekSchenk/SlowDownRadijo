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
        }
    }
}

/// Covers the first moments after launch with `SplashScreenView` — an exact
/// copy of the system launch screen, so the two read as one — then fades
/// it out as soon as the tab interface has drawn its first frame. The tab
/// view is mounted from the start, so its services warm up underneath.
private struct AppRootView: View {
    @State private var showSplash = true

    /// Just long enough for the home screen to lay out under the cover;
    /// the app itself is ready by then (the schedule ships in the bundle,
    /// and the slower start-up work waits until after it — see
    /// `RootTabView`'s autoplay and `PlayHistoryStore`).
    private static let hold: Duration = .milliseconds(80)

    var body: some View {
        ZStack {
            RootTabView()

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        // Dark only: no light mode, no appearance toggle.
        .preferredColorScheme(.dark)
        .appTextSizeLimit()
        .task {
            try? await Task.sleep(for: Self.hold)
            withAnimation(.easeOut(duration: 0.2)) {
                showSplash = false
            }
        }
    }
}
