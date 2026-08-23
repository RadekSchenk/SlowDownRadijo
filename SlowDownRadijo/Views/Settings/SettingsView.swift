import SwiftUI

/// Pushed from the hamburger menu — the appearance picker plus an autoplay
/// toggle. Language now lives back in `AppHeaderView` as a compact toggle
/// next to the hamburger. Feedback moved to its own menu item
/// (`FeedbackView`), always last in the menu.
struct SettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @AppStorage("autoplayEnabled") private var autoplayEnabled = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var isShowingPrivacyPolicy = false

    // TODO: placeholder — point this at the real hosted page once
    // PRIVACY_POLICY.md is published (see repo root).
    private static let privacyPolicyURL = URL(string: "https://slowdownradijo.cz/ochrana-osobnich-udaju/")!

    private var isEffectivelyDark: Bool {
        switch appearanceManager.appearance {
        case .system: return systemColorScheme == .dark
        case .light: return false
        case .dark: return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                BackHeaderView(title: L10n.settingsTitle, onBack: { dismiss() })
                autoplaySection
                appearanceSection
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

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(L10n.settingsAppearanceTitle)

            HStack(spacing: Theme.Spacing.sm) {
                appearanceOption(isDark: false, title: L10n.settingsAppearanceLight, icon: "sun.max.fill")
                appearanceOption(isDark: true, title: L10n.settingsAppearanceDark, icon: "moon.fill")
            }
        }
    }

    private func appearanceOption(isDark: Bool, title: String, icon: String) -> some View {
        let isSelected = isEffectivelyDark == isDark
        return Button {
            appearanceManager.appearance = isDark ? .dark : .light
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
            }
            .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? Theme.sunOrange : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.hairline(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
