import SwiftUI

/// Pushed from the hamburger menu — the autoplay toggle, the listening-stats
/// controls and the privacy policy, as a divider-separated list like the
/// home screen's "Pořady".
/// Language lives in `AppHeaderView`; feedback
/// and the news-notification toggle have their own homes in the menu.
struct SettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @AppStorage("autoplayEnabled") private var autoplayEnabled = true
    @AppStorage(StatsConfig.enabledKey) private var statsEnabled = true
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPrivacyPolicy = false
    @State private var isConfirmingStatsDeletion = false
    @State private var statsAlert: StatsAlert?

    private struct StatsAlert {
        let title: String
        var message: String?
    }

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
                    ListRow(title: L10n.settingsStatsTitle, subtitle: L10n.settingsStatsDescription) {
                        Toggle("", isOn: $statsEnabled)
                            .labelsHidden()
                            .tint(Theme.liveRed)
                    }

                    ListDivider()
                    Button {
                        isConfirmingStatsDeletion = true
                    } label: {
                        ListRow(title: L10n.settingsStatsDeleteTitle, subtitle: L10n.settingsStatsDeleteDescription) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)

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

                #if DEBUG
                Text("DEBUG · \(UserDefaults.standard.string(forKey: ListeningStatsStore.debugKey) ?? "no stats line yet")")
                    .font(Theme.Typography.Manrope.regular(size: 11, relativeTo: .caption2))
                    .foregroundStyle(Theme.subtleText)
                #endif
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
        .onChange(of: statsEnabled) { _, _ in
            ListeningTracker.shared.enabledPreferenceChanged()
        }
        .confirmationDialog(
            L10n.statsDeleteConfirmTitle,
            isPresented: $isConfirmingStatsDeletion,
            titleVisibility: .visible
        ) {
            Button(L10n.statsDeleteConfirmAction, role: .destructive) {
                Task {
                    do {
                        try await ListeningTracker.shared.deleteAllData()
                        statsAlert = StatsAlert(title: L10n.statsDeletedTitle)
                    } catch {
                        statsAlert = StatsAlert(title: L10n.statsDeleteFailedTitle, message: L10n.statsDeleteFailedMessage)
                    }
                }
            }
            Button(L10n.statsDeleteCancel, role: .cancel) {}
        } message: {
            Text(L10n.statsDeleteConfirmMessage)
        }
        .alert(
            statsAlert?.title ?? "",
            isPresented: Binding(
                get: { statsAlert != nil },
                set: { if !$0 { statsAlert = nil } }
            )
        ) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            if let message = statsAlert?.message {
                Text(message)
            }
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
