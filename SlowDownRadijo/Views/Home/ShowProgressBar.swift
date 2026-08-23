import SwiftUI

/// Shows how far the current programme block has progressed: the big
/// `NowPlayingWaveform` (while playing) sitting directly on top of a thin
/// fill track, start/end clock times below that, then "Pořad končí za 1h
/// 29 min" / "Další: <next show>" further below. The waveform lives here
/// (not as a sibling in `HomeView`) because Figma ties it tightly to the
/// track — 4pt gap between them, vs. 12pt everywhere else in this block —
/// so they read as one visual unit, not two independent pieces.
struct ShowProgressBar: View {
    @ObservedObject private var loc = LocalizationManager.shared

    let show: Show
    let progress: Double
    let remainingMinutes: Int
    let nextShow: Show?
    /// Whether to show `NowPlayingWaveform` above the track — removed
    /// from the layout entirely while paused, not dimmed (see
    /// `NowPlayingWaveform`).
    let isPlaying: Bool
    /// Forwarded to `NowPlayingWaveform` to trigger its reseed on track
    /// change — see that view for details.
    let waveformTrackID: AnyHashable

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                VStack(spacing: 4) {
                    if isPlaying {
                        NowPlayingWaveform(progress: progress, trackID: waveformTrackID)
                    }
                    progressTrack
                }

                HStack {
                    Text(show.start)
                        .foregroundStyle(Theme.lavender)
                    Spacer()
                    Text(show.end)
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(remainingLabel)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)

                if let nextShow {
                    Text(L10n.next(nextShow.name))
                        .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progressTrack: some View {
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

    private var remainingLabel: String {
        guard remainingMinutes > 0 else { return L10n.showEndingNow }
        return L10n.showEndsIn(Self.formatted(minutes: remainingMinutes))
    }

    private static func formatted(minutes: Int) -> String {
        guard minutes >= 60 else { return L10n.minutesShort(minutes) }
        let hours = minutes / 60
        let remainder = minutes % 60
        return L10n.durationShort(hours: hours, minutes: remainder)
    }
}
