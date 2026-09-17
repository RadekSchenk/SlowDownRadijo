import SwiftUI

/// Pushed from the hamburger menu — just an autoplay toggle now. Language
/// and the appearance toggle both live in `AppHeaderView` as compact
/// controls next to the hamburger. Feedback moved to its own menu item
/// (`FeedbackView`), always last in the menu.
struct SettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage("autoplayEnabled") private var autoplayEnabled = true
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPrivacyPolicy = false

    // TODO: placeholder — point this at the real hosted page once
    // PRIVACY_POLICY.md is published (see repo root).
    private static let privacyPolicyURL = URL(string: "https://slowdownradijo.cz/ochrana-osobnich-udaju/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                BackHeaderView(title: L10n.settingsTitle, onBack: { dismiss() })
                autoplaySection
                privacyPolicyRow
                aboutFooter
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            SafariView(url: Self.privacyPolicyURL)
        }
    }

    // MARK: - Autoplay

    private var autoplaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(L10n.settingsAutoplayTitle)

            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                Text(L10n.settingsAutoplayDescription)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)

                Spacer(minLength: Theme.Spacing.md)

                Toggle("", isOn: $autoplayEnabled)
                    .labelsHidden()
                    .tint(Theme.sunOrange)
            }
        }
    }

    // MARK: - Privacy policy

    private var privacyPolicyRow: some View {
        Button {
            isShowingPrivacyPolicy = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.settingsPrivacyPolicy)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared bits

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .title3))
            .foregroundStyle(Theme.textPrimary)
    }

    private var aboutFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return Text(L10n.settingsAbout(version: version, build: build))
            .font(Theme.Typography.Manrope.regular(size: 11, relativeTo: .caption2))
            .foregroundStyle(Theme.lavender)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
