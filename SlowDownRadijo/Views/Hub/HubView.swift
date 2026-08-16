import SwiftUI

/// The hamburger menu opened from `AppHeaderView` — everything that
/// doesn't belong on a primary tab: personal settings, the station's own
/// "Novinky" feed, notification preferences, and feedback (always last).
/// Presented as the sheet's root `NavigationStack`, so each row pushes on
/// top of it rather than opening as its own sheet.
struct HubView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    VStack(spacing: Theme.Spacing.sm) {
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

                        NavigationLink {
                            FavoritesView()
                        } label: {
                            HubRow(icon: "heart.fill", title: L10n.hubFavoritesRow, subtitle: L10n.hubFavoritesRowSubtitle)
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

private struct HubRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.sunOrange)
                .frame(width: 44, height: 44)
                .background(Theme.sunOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.lavender)
        }
        .padding(Theme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
        )
    }
}
