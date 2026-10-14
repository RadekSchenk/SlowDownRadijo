import SwiftUI
import UIKit
import UserNotifications

/// Settings ▸ Upozornění na pořady: every show once, each with its own
/// switch (the same choice as the bell in the Pořady list), and a way to
/// turn them all off. If iOS has notifications off for the app, a note at
/// the top says so and links to the system settings.
struct ShowRemindersView: View {
    @ObservedObject private var reminders = ShowReminderStore.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsBlocked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.showRemindersTitle, onBack: { dismiss() })

                Text(L10n.showRemindersIntro)
                    .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)

                if notificationsBlocked {
                    blockedNote
                }

                VStack(spacing: 0) {
                    ForEach(reminders.allShows) { show in
                        ListDivider()
                        ListRow(title: show.displayTitle, subtitle: show.hostName) {
                            Toggle("", isOn: binding(for: show))
                                .labelsHidden()
                                .tint(Theme.liveRed)
                        }
                    }
                    ListDivider()
                }

                if !reminders.followedIDs.isEmpty {
                    SecondaryActionButton(title: L10n.turnOffAllReminders) {
                        withAnimation(Motion.cardResize) {
                            reminders.unfollowAll()
                        }
                    }
                    .transition(.reveal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, Theme.Spacing.xl)
            .animation(Motion.cardResize, value: reminders.followedIDs.isEmpty)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await refreshAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            // Back from the iOS settings.
            if phase == .active { Task { await refreshAuthorization() } }
        }
    }

    private func binding(for show: Show) -> Binding<Bool> {
        Binding(
            get: { reminders.isFollowing(show) },
            set: { follow in
                Task {
                    if await reminders.setFollowing(show, follow) == .notAllowed {
                        notificationsBlocked = true
                        ToastCenter.shared.show(.notificationsBlocked)
                    }
                }
            }
        )
    }

    private var blockedNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.liveRed)
            Text(L10n.notificationsBlockedToast)
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.openSettingsAction)
                    .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.liveRed)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Only a refusal counts as blocked; "not asked yet" is asked on the
    /// first switch.
    private func refreshAuthorization() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsBlocked = status == .denied
        if status != .denied {
            reminders.reschedule()
        }
    }
}
