import SwiftUI

/// The flat progress-fill track shared between `ShowProgressBar` (home
/// screen's full now-playing detail) and `ShowCardView` (Program tab's
/// compact list row) — kept as one component (2026-08-23 unification) so
/// the exact styling (rounded rectangle, `Theme.liveRed` fill, hairline
/// track, 6pt height) can't drift between the two over time.
struct ShowProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.hairline(0.1))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.liveRed)
                    .frame(width: max(6, proxy.size.width * progress))
                    .animation(.linear(duration: 0.6), value: progress)
            }
        }
        .frame(height: 6)
    }
}
