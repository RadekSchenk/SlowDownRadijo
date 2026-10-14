import SwiftUI

/// How far the current programme block has got (Figma "Programme
/// progress", node 12318:5217): the block's start and end times, then a
/// thin rounded track underneath, 10pt apart. The equalizer that used to
/// sit on the track now flanks the show card (`CardSideEqualizer`), and
/// the remaining-time line moved next to the play button (`HomeView`).
struct ShowProgressBar: View {
    let show: Show
    let progress: Double
    /// Lights the glow at the head of the fill.
    var isPlaying = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False while off screen: coming back, the fill runs up from the
    /// start to where the show is now, once.
    @State private var hasRisen = false
    /// The glow's breath, in step with the ON-AIR dot.
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(show.start)
                    .foregroundStyle(Theme.mutedText)
                Spacer()
                Text(show.end)
                    .foregroundStyle(Theme.textPrimary)
            }
            .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))

            track
        }
    }

    /// 5pt, 3pt corners, white at 10% with a `liveRed` fill. Its own track
    /// rather than `ShowProgressTrack`, which the Pořady list still uses in
    /// its earlier style.
    ///
    /// Motion: the fill runs up to the current point when the tab appears
    /// (0.8s, slowing to a stop), then grows with the show as before.
    /// While the radio plays, a soft glow at its head breathes like the
    /// ON-AIR dot — "we're here now"; paused, it goes out. With Reduce
    /// Motion the fill just shows and the glow stays steady.
    private var track: some View {
        GeometryReader { proxy in
            let fillWidth = max(5, proxy.size.width * (hasRisen ? progress : 0))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.hairline(0.1))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.liveRed)
                    .frame(width: fillWidth)

                Circle()
                    .fill(Theme.liveRed)
                    .frame(width: 12, height: 12)
                    .blur(radius: 4)
                    .opacity(pulse || reduceMotion ? 0.9 : 0.35)
                    .opacity(isPlaying ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: isPlaying)
                    .offset(x: fillWidth - 6)
                    .allowsHitTesting(false)
            }
            .animation(Motion.smoothOut(0.6), value: progress)
        }
        .frame(height: 5)
        .onAppear {
            if reduceMotion {
                hasRisen = true
                return
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                hasRisen = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear {
            hasRisen = false
            pulse = false
        }
    }
}
