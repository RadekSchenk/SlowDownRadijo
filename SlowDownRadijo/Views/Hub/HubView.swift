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

                    VStack(spacing: Theme.Spacing.sm) {
                        // First and most prominent — see `whatsAppGreen` above.
                        Button {
                            openURL(Self.whatsAppURL)
                        } label: {
                            HubRow(title: L10n.hubWhatsAppRow, subtitle: L10n.hubWhatsAppRowSubtitle, tint: Self.whatsAppGreen) {
                                WhatsAppGlyph()
                            }
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
    let title: String
    let subtitle: String
    var tint: Color = Theme.sunOrange
    let icon: AnyView

    init(icon systemImage: String, title: String, subtitle: String, tint: Color = Theme.sunOrange) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.icon = AnyView(
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
        )
    }

    /// For rows that need a custom glyph instead of a plain SF Symbol —
    /// currently just the WhatsApp row (see `WhatsAppGlyph`).
    init(title: String, subtitle: String, tint: Color = Theme.sunOrange, @ViewBuilder icon: () -> some View) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.icon = AnyView(icon())
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            icon
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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

/// A simplified, monochrome silhouette of WhatsApp's phone-in-speech-bubble
/// mark — deliberately not their official logo (a colored, licensed
/// trademark asset that would also look out of place among this menu's
/// flat single-tone icons). Just enough shape to read as "chat", which
/// alongside the visible "WhatsApp" text label is unambiguous.
private struct WhatsAppGlyph: View {
    var body: some View {
        ZStack {
            ChatBubbleOutline()
                .stroke(lineWidth: 1.6)
            Image(systemName: "phone.fill")
                .font(.system(size: 9, weight: .semibold))
                .offset(y: -1.5)
        }
        .frame(width: 22, height: 20)
    }
}

private struct ChatBubbleOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let bodyHeight = rect.height * 0.78
        let bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bodyHeight)
        var path = Path(roundedRect: bodyRect, cornerRadius: bodyHeight / 2)
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: bodyRect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: bodyRect.maxY - 1))
        return path
    }
}
