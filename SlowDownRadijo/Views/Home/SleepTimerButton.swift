import SwiftUI

enum SleepTimerOption: CaseIterable, Identifiable {
    case min5, min10, min15, min30, min45, hour1, endOfShow

    var id: Self { self }

    /// How the option appears in analytics.
    var analyticsName: String {
        switch self {
        case .min5: return "5m"
        case .min10: return "10m"
        case .min15: return "15m"
        case .min30: return "30m"
        case .min45: return "45m"
        case .hour1: return "60m"
        case .endOfShow: return "end_of_show"
        }
    }

    /// Spoken label (VoiceOver), e.g. "15 minut".
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

    /// The big number and the small unit on the option's tile.
    var tileValue: String {
        switch self {
        case .min5: return "5"
        case .min10: return "10"
        case .min15: return "15"
        case .min30: return "30"
        case .min45: return "45"
        case .hour1: return "1"
        case .endOfShow: return ""
        }
    }

    var tileUnit: String {
        self == .hour1 ? L10n.hoursUnit : L10n.minutesUnit
    }

    /// The fixed-length options, laid out as the sheet's tile grid.
    static let durations: [SleepTimerOption] = [.min5, .min10, .min15, .min30, .min45, .hour1]
}

/// A plain link row under the show progress bar: tapping opens
/// `SleepTimerSheet`, and while a timer is running the row's own label
/// switches to show the remaining time instead of the "set a timer" prompt.
struct SleepTimerButton: View {
    @ObservedObject var player: RadioPlayerService
    /// Needed to resolve "Konec pořadu" to an actual fire date.
    let currentShowEndDate: Date?

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isShowingSheet = false
    /// The option behind the running timer, highlighted in the sheet.
    @State private var activeOption: SleepTimerOption?
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingSheet = true
        } label: {
            // Figma "Sleep timer" (node 12318:5226): text first, the moon
            // after it, 8pt apart.
            HStack(spacing: 8) {
                Text(label)
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                // Plain filled crescent, 15pt — Figma's icon has no "zzz"
                // sleep marks.
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 15, height: 15)
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
        .onReceive(ticker) { now = $0 }
        .onChange(of: player.sleepTimerFireDate) { _, fireDate in
            if fireDate == nil { activeOption = nil }
        }
        .sheet(isPresented: $isShowingSheet) {
            SleepTimerSheet(
                activeOption: activeOption,
                fireDate: player.sleepTimerFireDate,
                currentShowEndDate: currentShowEndDate,
                onSelect: apply,
                onCancel: {
                    player.cancelSleepTimer()
                    activeOption = nil
                }
            )
        }
    }

    private var label: String {
        guard let fireDate = player.sleepTimerFireDate else { return L10n.setSleepTimer }
        return L10n.turnsOffIn(Self.remainingLabel(until: fireDate, now: now))
    }

    private func apply(_ option: SleepTimerOption) {
        if let duration = option.duration {
            player.scheduleSleepTimer(duration: duration)
        } else if let currentShowEndDate {
            player.scheduleSleepTimer(fireDate: currentShowEndDate)
        } else {
            return
        }
        activeOption = option
        Analytics.shared.track(.sleepTimerSet(option: option.analyticsName))
    }

    static func remainingLabel(until fireDate: Date, now: Date) -> String {
        let remaining = max(0, Int(fireDate.timeIntervalSince(now)))
        let minutes = (remaining + 59) / 60
        guard minutes >= 60 else { return L10n.minutesShort(minutes) }
        return L10n.durationShort(hours: minutes / 60, minutes: minutes % 60)
    }
}

/// The sleep-timer picker, in the app's own look rather than a system
/// action sheet: a short bottom sheet on the bottom bar's colour, with the
/// durations as tiles like the Pořady day picker (big number, small unit),
/// "Konec pořadu" as a full-width row with the show's end time, and — while
/// a timer runs — the countdown and a cancel button.
struct SleepTimerSheet: View {
    let activeOption: SleepTimerOption?
    let fireDate: Date?
    let currentShowEndDate: Date?
    let onSelect: (SleepTimerOption) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(SleepTimerOption.durations) { option in
                        durationTile(option)
                    }
                }

                endOfShowRow
            }

            if fireDate != nil {
                SecondaryActionButton(title: L10n.cancelTimer) {
                    onCancel()
                    dismiss()
                }
                .transition(.reveal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.cardResize, value: fireDate != nil)
        .presentationDetents([.height(fireDate == nil ? 352 : 428), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Theme.statsCard)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.liveRed)
                Text(L10n.sleepTimerSheetTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
            }

            if let fireDate {
                // Counts down live while the sheet is open.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    PopNumberText(
                        text: L10n.turnsOffIn(SleepTimerButton.remainingLabel(until: fireDate, now: context.date)),
                        font: Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline),
                        color: Theme.liveRed
                    )
                }
            } else {
                Text(L10n.sleepTimerHint)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }

    private func durationTile(_ option: SleepTimerOption) -> some View {
        let isActive = option == activeOption && fireDate != nil
        return Button {
            onSelect(option)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text(option.tileValue)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .manropeLineHeight(34, fontSize: 28)
                Text(option.tileUnit)
                    .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.mutedText)
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                isActive ? Theme.liveRed : Theme.statsCardRaised,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Full-width "Konec pořadu" with the end time on the right. Disabled
    /// (dimmed) when there's no current show to end with.
    private var endOfShowRow: some View {
        let isActive = activeOption == .endOfShow && fireDate != nil
        let isEnabled = currentShowEndDate != nil
        return Button {
            onSelect(.endOfShow)
            dismiss()
        } label: {
            HStack {
                Text(L10n.endOfShow)
                    .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                if let currentShowEndDate {
                    Text(L10n.atTime(currentShowEndDate.formatted(date: .omitted, time: .shortened)))
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(isActive ? Theme.textPrimary : Theme.mutedText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                isActive ? Theme.liveRed : Theme.statsCardRaised,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(TilePressStyle())
        .disabled(!isEnabled)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Tiles give a little under the finger (library "quick" timing).
private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.smoothOut(Motion.quick), value: configuration.isPressed)
    }
}
