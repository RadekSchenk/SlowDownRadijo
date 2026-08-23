import SwiftUI

/// The hamburger menu opened from `AppHeaderView` — everything that
/// doesn't belong on a primary tab: personal settings, the station's own
/// "Novinky" feed, notification preferences, and feedback (always last).
/// Presented as the sheet's root `NavigationStack`, so each row pushes on
/// top of it rather than opening as its own sheet.
struct HubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// WhatsApp's own brand green — a deliberate exception to this app's
    /// usual "keep third-party touchpoints in-house-styled" rule (see
    /// `SpotifyPillButton`, `SocialLinksRow`). The station leans on this
    /// channel heavily on-air, so it gets first position and its own color
    /// to stand out from the lower-priority "also follow us" social row.
    private static let whatsAppGreen = Color(red: 0.145, green: 0.827, blue: 0.400)
    private static let whatsAppURL = URL(string: "https://wa.me/420720600811")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    // Flat list (2026-08-23 redesign) — no per-row bordered
                    // card anymore, rows sit directly on the page
                    // background separated by hairlines, same "Line 5"
                    // pattern as the home screen's "Co hrálo" list
                    // (`Theme.lavender.opacity(0.2)`). `HubRow` draws its
                    // own trailing divider; this just adds the leading one
                    // to bound the list on both ends, matching Figma.
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Theme.lavender.opacity(0.2))
                            .frame(height: 1)

                        // First and most prominent — see `whatsAppGreen` above.
                        Button {
                            openURL(Self.whatsAppURL)
                        } label: {
                            HubRow(icon: "message.fill", title: L10n.hubWhatsAppRow, subtitle: L10n.hubWhatsAppRowSubtitle, tint: Self.whatsAppGreen)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SettingsView()
                        } label: {
                            HubRow(icon: "gearshape.fill", title: L10n.hubSettingsRow, subtitle: L10n.hubSettingsRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            NewsListView()
                        } label: {
                            HubRow(icon: "newspaper.fill", title: L10n.hubNewsRow, subtitle: L10n.hubNewsRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            NotificationsView()
                        } label: {
                            HubRow(icon: "bell.fill", title: L10n.hubNotificationsRow, subtitle: L10n.hubNotificationsRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        // Always last among the menu rows, per explicit request.
                        NavigationLink {
                            FeedbackView()
                        } label: {
                            HubRow(icon: "envelope.fill", title: L10n.hubFeedbackRow, subtitle: L10n.hubFeedbackRowSubtitle)
                        }
                        .buttonStyle(.plain)
                    }

                    socialSection
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var socialSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(L10n.hubSocialTitle)
                .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
                .frame(maxWidth: .infinity, alignment: .center)

            SocialLinksRow()
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.hubTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Theme.hairline(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// A single menu row — icon, title/subtitle, trailing arrow. Icons/tints
/// per call site are unchanged from before this redesign (WhatsApp keeps
/// its own green, everything else keeps `Theme.sunOrange`); only the
/// container styling changed: flat 84pt row (was a bordered, rounded
/// card), icon chip corner radius 12→2 and tint opacity 12%→20%, bigger
/// title/subtitle type, and the trailing chevron swapped for a bolder
/// rightward arrow in `Theme.gold` (`#d4a24c` — matches the Figma asset's
/// literal fill exactly) instead of `Theme.lavender`.
private struct HubRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.sunOrange

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 2, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .tracking(0.14)
                        .foregroundStyle(Theme.lavender)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .frame(height: 84)

            Rectangle()
                .fill(Theme.lavender.opacity(0.2))
                .frame(height: 1)
        }
    }
}
