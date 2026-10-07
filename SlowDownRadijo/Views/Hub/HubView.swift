import SwiftUI

/// The hamburger menu opened from `AppHeaderView` — everything that
/// doesn't belong on a primary tab: WhatsApp, settings, the station's own
/// "Novinky" feed (which also holds its notification toggle), and feedback
/// (always last). Presented as the sheet's root `NavigationStack`, so each
/// row pushes on top of it rather than opening as its own sheet.
///
/// Styled after the home screen: 20pt margins, 24pt headings, and the menu
/// itself as a divider-separated list like "Pořady".
struct HubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private static let whatsAppURL = URL(string: "https://wa.me/420720600811")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    VStack(spacing: 0) {
                        // First and most prominent — the station leans on
                        // this channel heavily on-air.
                        ListDivider()
                        Button {
                            openURL(Self.whatsAppURL)
                        } label: {
                            row(icon: "message.fill", title: L10n.hubWhatsAppRow, subtitle: L10n.hubWhatsAppRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        ListDivider()
                        NavigationLink {
                            SettingsView()
                        } label: {
                            row(icon: "gearshape.fill", title: L10n.hubSettingsRow, subtitle: L10n.hubSettingsRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        ListDivider()
                        NavigationLink {
                            NewsListView()
                        } label: {
                            row(icon: "newspaper.fill", title: L10n.hubNewsRow, subtitle: L10n.hubNewsRowSubtitle)
                        }
                        .buttonStyle(.plain)

                        // Always last among the menu rows, per explicit request.
                        ListDivider()
                        NavigationLink {
                            FeedbackView()
                        } label: {
                            row(icon: "envelope.fill", title: L10n.hubFeedbackRow, subtitle: L10n.hubFeedbackRowSubtitle)
                        }
                        .buttonStyle(.plain)
                    }

                    socialSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.hubTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            HeaderIconButton(systemName: "xmark") { dismiss() }
                .accessibilityLabel(L10n.close)
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        ListRow(title: title, subtitle: subtitle) {
            ListRowIcon(systemName: icon)
        } trailing: {
            ListRowChevron()
        }
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.hubSocialTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)

            SocialLinksRow()
        }
    }
}
