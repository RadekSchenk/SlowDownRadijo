import SwiftUI

/// Pushed from the hamburger menu — the autoplay toggle and the privacy
/// policy, as a divider-separated list like the home screen's "Pořady".
/// Language and the light/dark toggle live in `AppHeaderView`; feedback
/// and the news-notification toggle have their own homes in the menu.
struct SettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage("autoplayEnabled") private var autoplayEnabled = true
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPrivacyPolicy = false

    private static let privacyPolicyURL = URL(string: "https://slowdownradijo.cz/ochrana-osobnich-udaju/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.settingsTitle, onBack: { dismiss() })

                VStack(spacing: 0) {
                    ListDivider()
                    ListRow(title: L10n.settingsAutoplayTitle, subtitle: L10n.settingsAutoplayDescription) {
                        Toggle("", isOn: $autoplayEnabled)
                            .labelsHidden()
                            .tint(Theme.liveRed)
                    }

                    ListDivider()
                    Button {
                        isShowingPrivacyPolicy = true
                    } label: {
                        ListRow(title: L10n.settingsPrivacyPolicy) {
                            ListRowChevron()
                        }
                    }
                    .buttonStyle(.plain)
                    ListDivider()
                }

                aboutFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            SafariView(url: Self.privacyPolicyURL)
        }
    }

    private var aboutFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return Text(L10n.settingsAbout(version: version, build: build))
            .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .footnote))
            .foregroundStyle(Theme.subtleText)
    }
}
