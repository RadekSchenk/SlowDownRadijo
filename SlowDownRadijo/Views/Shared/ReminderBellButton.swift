import SwiftUI
import UIKit

/// The bell next to a show in the Pořady list: follow / unfollow its start
/// notification (`ShowReminderStore`), confirmed by a toast.
///
/// Motion from the transitions.dev library: the outline and filled bell
/// swap with P5 (icon swap); switching on also rings the bell once — P12's
/// shake (+, −, +, settle, 280ms) applied as a swing around the bell's top.
/// Reduce Motion keeps only the swap.
struct ReminderBellButton: View {
    let show: Show

    @ObservedObject private var reminders = ShowReminderStore.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringCount = 0

    var body: some View {
        let isOn = reminders.isFollowing(show)

        Button {
            Task { await toggle() }
        } label: {
            ZStack {
                Image(systemName: isOn ? "bell.fill" : "bell")
                    .id(isOn)
                    .transition(.iconSwap)
            }
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isOn ? Theme.liveRed : Theme.mutedText)
            .keyframeAnimator(initialValue: 0.0, trigger: ringCount) { content, angle in
                content.rotationEffect(.degrees(angle), anchor: .top)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(16, duration: 0.08)
                    CubicKeyframe(-16, duration: 0.08)
                    CubicKeyframe(10, duration: 0.06)
                    CubicKeyframe(0, duration: 0.06)
                }
            }
            .animation(Motion.iconSwap, value: isOn)
            .frame(width: 44, height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.reminderBellLabel(show: show.displayTitle))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func toggle() async {
        let outcome = await reminders.toggle(show)
        switch outcome {
        case .enabled:
            Analytics.shared.track(.showReminderChanged(showID: show.id, isOn: true, source: "bell"))
            if !reduceMotion { ringCount += 1 }
            ToastCenter.shared.show(.init(
                systemImage: "bell.fill",
                message: L10n.reminderOnToast(show: show.displayTitle, next: reminders.nextAiringLabel(for: show))
            ))
        case .disabled:
            Analytics.shared.track(.showReminderChanged(showID: show.id, isOn: false, source: "bell"))
            ToastCenter.shared.show(.init(
                systemImage: "bell.slash",
                message: L10n.reminderOffToast(show: show.displayTitle)
            ))
        case .notAllowed:
            ToastCenter.shared.show(.notificationsBlocked)
        }
    }
}

extension ToastCenter.Toast {
    /// Notifications are off for the app in iOS: say so, offer the way there.
    @MainActor
    static var notificationsBlocked: ToastCenter.Toast {
        .init(
            systemImage: "bell.slash",
            message: L10n.notificationsBlockedToast,
            actionTitle: L10n.openSettingsAction,
            action: {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }
}
