import SwiftUI

enum SleepTimerOption: CaseIterable, Identifiable {
    case min5, min10, min15, min30, min45, hour1, endOfShow

    var id: Self { self }

    var label: String {
        switch self {
        case .min5: return L10n.minutesOption(5)
        case .min10: return L10n.minutesOption(10)
        case .min15: return L10n.minutesOption(15)
        case .min30: return L10n.minutesOption(30)
        case .min45: return L10n.minutesOption(45)
        case .hour1: return L10n.oneHour
        case .endOfShow: return L10n.endOfShow
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .min5: return 5 * 60
        case .min10: return 10 * 60
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .min45: return 45 * 60
        case .hour1: return 60 * 60
        case .endOfShow: return nil
        }
    }
}

/// A plain link row under the show progress bar: tapping opens the system
/// action-sheet style picker (5/10/15/30/45 min, 1h, or end-of-show), and
/// while a timer is running the row's own label switches to show the
/// remaining time instead of the "set a timer" prompt.
struct SleepTimerButton: View {
    @ObservedObject var player: RadioPlayerService
    /// Needed to resolve "Konec pořadu" to an actual fire date.
    let currentShowEndDate: Date?

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isShowingDialog = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingDialog = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
            }
            .foregroundStyle(Theme.lavender)
        }
        .buttonStyle(.plain)
        .onReceive(ticker) { now = $0 }
        .confirmationDialog(L10n.sleepTimerTitle, isPresented: $isShowingDialog, titleVisibility: .visible) {
            ForEach(SleepTimerOption.allCases) { option in
                Button(option.label) { apply(option) }
            }
            if player.sleepTimerFireDate != nil {
                Button(L10n.cancelTimer, role: .destructive) {
                    player.cancelSleepTimer()
                }
            }
        }
    }

    private var label: String {
        guard let fireDate = player.sleepTimerFireDate else { return L10n.setSleepTimer }
        return L10n.turnsOffIn(remainingLabel(until: fireDate))
    }

    private func apply(_ option: SleepTimerOption) {
        if let duration = option.duration {
            player.scheduleSleepTimer(duration: duration)
        } else if let currentShowEndDate {
            player.scheduleSleepTimer(fireDate: currentShowEndDate)
        }
    }

    private func remainingLabel(until fireDate: Date) -> String {
        let remaining = max(0, Int(fireDate.timeIntervalSince(now)))
        let minutes = (remaining + 59) / 60
        guard minutes >= 60 else { return L10n.minutesShort(minutes) }
        return L10n.durationShort(hours: minutes / 60, minutes: minutes % 60)
    }
}
