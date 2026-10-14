import SwiftUI

/// How far the current programme block has got (Figma "Programme
/// progress", node 12318:1925): a thin rounded track, then the block's
/// start and end times underneath, 10pt apart. The equalizer that used to
/// sit on the track now flanks the show card (`CardSideEqualizer`), and
/// the remaining-time line moved next to the play button (`HomeView`).
struct ShowProgressBar: View {
    let show: Show
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            track

            HStack {
                Text(show.start)
                    .foregroundStyle(Theme.mutedText)
                Spacer()
                Text(show.end)
                    .foregroundStyle(Theme.textPrimary)
            }
            .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
        }
    }

    /// 5pt, 3pt corners, white at 10% with a `liveRed` fill. Its own track
    /// rather than `ShowProgressTrack`, which the Pořady list still uses in
    /// its earlier style.
    private var track: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.hairline(0.1))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.liveRed)
                    .frame(width: max(5, proxy.size.width * progress))
                    .animation(Motion.smoothOut(0.6), value: progress)
            }
        }
        .frame(height: 5)
    }
}
