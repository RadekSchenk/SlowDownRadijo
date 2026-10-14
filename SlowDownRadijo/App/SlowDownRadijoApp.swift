import SwiftUI

@main
struct SlowDownRadijoApp: App {
    init() {
        NewsNotificationManager.configureForegroundPresentation()
        ShowReminderStore.registerNotificationCategory()
        if !Diag.on("noAnalytics") {
            Analytics.shared.configure()
        }
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
    /// the app itself is ready by then (the schedule ships in the bundle).
    private static let hold: Duration = .milliseconds(250)

    var body: some View {
        ZStack {
            if Diag.on("bare") {
                DiagBareView()
            } else {
                RootTabView()
            }

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        // Dark only: no light mode, no appearance toggle.
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: Self.hold)
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }
    }
}

/// Diagnostics only (`-diag.bare YES`): the simplest possible view with its
/// own state, in RootTabView's place.
private struct DiagBareView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 40) {
            Text("bare \(count)")
                .accessibilityIdentifier("diag.bare.text")
            Button("Bump") { count += 1 }
                .accessibilityIdentifier("diag.bare.button")
        }
    }
}
