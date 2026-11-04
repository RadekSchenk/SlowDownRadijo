import SwiftUI

/// A pixel-for-pixel copy of the system launch screen (`UILaunchScreen` in
/// `project.yml`: the `LaunchBackground` colour with `LaunchLogo` centred
/// at its own size), laid over the app for a moment after launch and then
/// faded out (see `AppRootView`). Being identical to what iOS shows while
/// the app loads, the handover can't be seen: the listener gets one launch
/// screen that dissolves into the app, not two different ones in a row.
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
            // No resizing: iOS draws the launch image at its point size,
            // centred on the whole screen.
            Image("LaunchLogo")
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    SplashScreenView()
}
