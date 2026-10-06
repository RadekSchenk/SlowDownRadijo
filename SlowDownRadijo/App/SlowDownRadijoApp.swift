import SwiftUI

@main
struct SlowDownRadijoApp: App {
    init() {
        NewsNotificationManager.configureForegroundPresentation()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

/// Shows the splash screen briefly on cold launch, then reveals the tab
/// interface underneath. The tab view is mounted from the start (not after
/// a delay) so its services start warming up immediately; the splash is
/// purely a visual overlay.
private struct AppRootView: View {
    @State private var showSplash = true

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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}
