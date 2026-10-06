import SwiftUI

/// Shows how far the current programme block has progressed: the big
/// `NowPlayingWaveform` (while playing) sitting directly on top of a thin
/// fill track, start/end clock times above them, then "Pořad končí za 1h
/// 29 min" below. No "next show" line — Figma dropped it, the home
/// screen's Pořady list already shows what follows. The waveform lives here
/// (not as a sibling in `HomeView`) because Figma ties it tightly to the
/// track — 4pt gap between them, vs. 12pt everywhere else in this block —
/// so they read as one visual unit, not two independent pieces.
struct ShowProgressBar: View {
    @ObservedObject private var loc = LocalizationManager.shared

    let show: Show
    let progress: Double
    let remainingMinutes: Int
    /// Whether to show `NowPlayingWaveform` above the track — removed
    /// from the layout entirely while paused, not dimmed (see
    /// `NowPlayingWaveform`).
    let isPlaying: Bool
    /// Forwarded to `NowPlayingWaveform` to trigger its reseed on track
    /// change — see that view for details.
    let waveformTrackID: AnyHashable

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Figma "progress-labels" sit *above* the track, 12pt apart.
            VStack(spacing: 12) {
                HStack {
                    Text(show.start)
                        .foregroundStyle(Theme.mutedText)
                    Spacer()
                    Text(show.end)
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))

                VStack(spacing: 4) {
                    if isPlaying {
                        NowPlayingWaveform(progress: progress, trackID: waveformTrackID)
                            .transition(.reveal)
                    }
                    ShowProgressTrack(progress: progress)
                }
                // The equalizer comes and goes with the play state; the rest
                // of the card follows its height (library P4 / P22).
                .animation(Motion.cardResize, value: isPlaying)
            }

            // The minutes count down with the number pop-in (library P9).
            PopNumberText(
                text: remainingLabel,
                font: Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline),
                color: Theme.mutedText
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
