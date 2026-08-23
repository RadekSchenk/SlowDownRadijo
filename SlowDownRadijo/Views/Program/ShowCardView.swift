import SwiftUI

/// A single programme row, per the "schedule-screen" Figma redesign: a
/// leading two-line time column, 56×56 artwork, then the show title —
/// which, when the block is airing right now, also carries the shared
/// `OnAirBadge` plus a live progress bar underneath. The whole row gets a
/// subtle red full-bleed tint while live.
struct ShowCardView: View {
    let show: Show
    let isLive: Bool
    let progress: Double

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(show.start)
                Text(show.end)
            }
            .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(Theme.lavender)
            .frame(width: 56, alignment: .leading)

            // 2pt matches the home screen's track artwork (`TrackDetailsRow`),
            // not the previous 12pt — unified 2026-08-23.
            RemoteArtworkView(url: show.imageURL, cornerRadius: 2)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(show.name)
                        .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let language = show.language {
                        Text(language)
                            .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption2))
                            .foregroundStyle(Color(hex: 0xF5D0FE))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.hairline(0.08), in: Capsule())
                    }

                    if isLive {
                        OnAirBadge()
                    }
                }

                // Shares `ShowProgressTrack` with the home screen's
                // `ShowProgressBar` — same flat-rectangle/liveRed styling,
                // unified 2026-08-23 (was its own rounded sunOrange
                // Capsule bar before). Deliberately not the full
                // `ShowProgressBar` component: its remaining-time text,
                // next-show line, and waveform equalizer belong to the
                // home screen's now-playing detail, not a compact list row.
                if isLive {
                    ShowProgressTrack(progress: progress)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isLive ? Color(hex: 0xD91F1F).opacity(0.12) : Color.clear)
    }
}
