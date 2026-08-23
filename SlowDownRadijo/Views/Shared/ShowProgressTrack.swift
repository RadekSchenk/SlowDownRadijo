import SwiftUI

/// The flat progress-fill track shared between `ShowProgressBar` (home
/// screen's full now-playing detail) and `ShowCardView` (Program tab's
/// compact list row) — kept as one component (2026-08-23 unification) so
/// the exact styling (flat rectangle, `Theme.liveRed` fill, hairline
/// track, 4pt height) can't drift between the two over time.
struct ShowProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.hairline(0.08))

                Rectangle()
                    .fill(Theme.liveRed)
                    .frame(width: max(6, proxy.size.width * progress))
                    .animation(.linear(duration: 0.6), value: progress)
            }
        }
        .frame(height: 4)
    }
}
