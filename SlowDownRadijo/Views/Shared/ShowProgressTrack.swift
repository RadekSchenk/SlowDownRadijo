import SwiftUI

/// The flat progress-fill track of `ShowCardView` (Program tab's compact
/// list row): square ends, `Theme.liveRed` fill, `#b8afdc` unplayed part,
/// 6pt height. The home screen's card has its own rounded track (see
/// `ShowProgressBar`).
struct ShowProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.equalizerUnplayed)

                Rectangle()
                    .fill(Theme.liveRed)
                    .frame(width: max(6, proxy.size.width * progress))
                    .animation(Motion.smoothOut(0.6), value: progress)
            }
        }
        .frame(height: 6)
    }
}
