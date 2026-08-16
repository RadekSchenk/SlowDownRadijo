import SwiftUI

/// Pushed from the hamburger menu — for now, a single toggle: notify when
/// a new "Novinka" is published (on by default). More notification types
/// can join this screen later.
struct NotificationsView: View {
    @AppStorage("newsNotificationsEnabled") private var newsNotificationsEnabled = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                BackHeaderView(title: L10n.notificationsTitle, onBack: { dismiss() })

                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.notificationsNewPostTitle)
                            .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .headline))
                            .foregroundStyle(Theme.textPrimary)
                        Text(L10n.notificationsNewPostDescription)
                            .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                            .foregroundStyle(Theme.lavender)
                    }

                    Spacer(minLength: Theme.Spacing.md)

                    Toggle("", isOn: $newsNotificationsEnabled)
                        .labelsHidden()
                        .tint(Theme.sunOrange)
                }
                .padding(Theme.Spacing.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
                        .allowsHitTesting(false)
                )
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: newsNotificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task { await NewsNotificationManager.requestAuthorizationIfNeeded() }
        }
    }
}
