import SwiftUI

/// Figma "Budík s rádiem", C1: under "Nastavit časovač vypnutí" — falling
/// asleep and waking up in one place. "Budit se rádiem ☀" without an alarm
/// (or with one turned off), "Vzbudí tě rádio · Po–Pá 6:30" with one. Only
/// on iOS 26+ (AlarmKit).
struct RadioAlarmLink: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var alarm = RadioAlarmStore.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isShowingSheet = false

    var body: some View {
        Button {
            isShowingSheet = true
        } label: {
            // One text with the sun at its end: on two lines it follows the
            // last word instead of floating beside the block.
            (Text(alarm.settings.isOn ? L10n.alarmRow(RadioAlarmFormat.summary(alarm.settings)) : L10n.alarmSet)
                .foregroundStyle(Theme.textPrimary)
             // Non-breaking space and word joiner: the sun never wraps alone.
             + Text("\u{00A0}\u{00A0}\u{2060}")
             + Text(Image(systemName: "sunrise.fill"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(alarm.settings.isOn ? Color(hex: 0xF2C25B) : Theme.textPrimary))
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingSheet) {
            RadioAlarmSheet(scheduleStore: scheduleStore)
                .appTextSizeLimit()
        }
    }
}

/// Figma C2 / C3: the alarm's settings — the time on the system wheel, the
/// days, snooze length, who'll be on air and a test alarm. Nothing applies
/// until "Uložit budík" (new or turned off) / "Uložit změny" (on; enabled
/// only after a change). "Vypnout budík" turns it off and keeps the rest.
struct RadioAlarmSheet: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var alarm = RadioAlarmStore.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RadioAlarmSettings()
    @State private var time = Date()
    @State private var isSaving = false

    private var isOn: Bool { alarm.settings.isOn }
    private var hasChanges: Bool { !draft.sameAlarm(as: alarm.settings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.alarmTitle)
                        .font(Theme.Typography.Heading.hero)
                        .foregroundStyle(Theme.textPrimary)
                    if isOn, let fire = alarm.nextFire {
                        Text(L10n.alarmStatusOn(RadioAlarmFormat.when(fire)))
                            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Color(hex: 0x7FD49B))
                    } else {
                        Text(L10n.alarmIntro)
                            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.mutedText)
                    }
                }

                if alarm.authorization == .denied {
                    VStack(alignment: .leading, spacing: 12) {
                        StatsBodyText(L10n.alarmDenied, color: Theme.textPrimary)
                        SecondaryActionButton(title: L10n.alarmOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onChange(of: time) { _, newValue in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        draft.hour = parts.hour ?? 6
                        draft.minute = parts.minute ?? 30
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.alarmRepeat)
                        .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                    HStack(spacing: 6) {
                        ForEach(RadioAlarmFormat.weekOrder, id: \.self) { weekday in
                            dayChip(weekday)
                        }
                    }
                }

                VStack(spacing: 0) {
                    ListRow(title: L10n.alarmSnooze, subtitle: L10n.alarmSnoozeDescription) {
                        Menu {
                            Picker(L10n.alarmSnooze, selection: $draft.snoozeMinutes) {
                                ForEach(RadioAlarmSettings.snoozeChoices, id: \.self) { Text(L10n.alarmMinutes($0)).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(L10n.alarmMinutes(draft.snoozeMinutes))
                                    .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .subheadline))
                                Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let fire = RadioAlarmStore.nextFire(after: Date(), settings: draft),
                   let show = scheduleStore.show(at: fire) {
                    HStack(spacing: 12) {
                        ShowArtworkThumb(show: show)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.alarmWakesYou(RadioAlarmFormat.when(fire)))
                                .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                                .foregroundStyle(Theme.mutedText)
                            Text(show.displayTitle)
                                .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            if let host = show.hostName {
                                Text(host)
                                    .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                                    .foregroundStyle(Theme.mutedText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                VStack(spacing: 12) {
                    SecondaryActionButton(title: L10n.alarmTest) {
                        Task { await alarm.test() }
                    }
                    PrimaryActionButton(
                        title: isOn ? L10n.alarmSaveChanges : L10n.alarmSave,
                        isEnabled: !isSaving && (!isOn || hasChanges)
                    ) {
                        save()
                    }
                    if isOn {
                        Button(action: turnOff) {
                            Text(L10n.alarmTurnOff)
                                .font(Theme.Typography.Copy.button)
                                .foregroundStyle(Color(hex: 0xFF6B84))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.liveRed, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                StatsBodyText(isOn ? L10n.alarmTurnOffNote : L10n.alarmFootnoteIOS, color: Theme.subtleText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Theme.statsCard)
        .onAppear {
            draft = alarm.settings
            time = Calendar.current.date(bySettingHour: draft.hour, minute: draft.minute, second: 0, of: Date()) ?? Date()
        }
        .task { await alarm.sync() }
    }

    private func save() {
        isSaving = true
        Task {
            let saved = await alarm.save(draft)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func turnOff() {
        Task {
            await alarm.turnOff()
            dismiss()
        }
    }

    private func dayChip(_ weekday: Int) -> some View {
        let isOn = draft.weekdays.contains(weekday)
        return Button {
            if isOn { draft.weekdays.remove(weekday) } else { draft.weekdays.insert(weekday) }
        } label: {
            Text(L10n.shortDayName(weekday: weekday))
                .font(isOn ? Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote)
                           : Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                .foregroundStyle(isOn ? Theme.textPrimary : Theme.mutedText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isOn ? Theme.liveRed : Color.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Figma B5 and B6 on the home screen: after the alarm started the radio
/// ("Dobré ráno" — snooze or done, gone by itself after 15 minutes), and
/// while snoozed from the app (when it plays again, or cancel).
struct RadioAlarmCard: View {
    @ObservedObject private var alarm = RadioAlarmStore.shared
    @ObservedObject private var loc = LocalizationManager.shared

    private struct Action {
        let title: String
        let run: () -> Void
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(at: context.date)
        }
    }

    @ViewBuilder
    private func content(at now: Date) -> some View {
        if let until = alarm.snoozedUntil, until > now {
            card(
                title: L10n.alarmSnoozedTitle,
                subtitle: L10n.alarmSnoozedUntil(RadioAlarmFormat.time(until)),
                colors: [Color(hex: 0x3B1F7A), Color(hex: 0x241C3A)],
                primary: Action(title: L10n.alarmCancel, run: cancelSnooze),
                secondary: Action(title: L10n.alarmPlayNow, run: playNow)
            )
        } else if let woke = alarm.wokeAt, now.timeIntervalSince(woke) < 15 * 60 {
            card(
                title: L10n.alarmGoodMorning,
                subtitle: L10n.alarmPlaying(RadioAlarmFormat.time(woke)),
                colors: [Color(hex: 0xB8541C), Color(hex: 0x7A1838)],
                primary: alarm.canSnooze ? Action(title: L10n.alarmSnoozeFor(alarm.settings.snoozeMinutes), run: snooze) : nil,
                secondary: Action(title: L10n.alarmDone, run: done)
            )
        }
    }

    private func cancelSnooze() { alarm.cancelSnooze() }
    private func playNow() { alarm.cancelSnooze(); alarm.wake() }
    private func snooze() { Task { await alarm.snooze() } }
    private func done() { alarm.done() }

    private func card(title: String, subtitle: String, colors: [Color], primary: Action?, secondary: Action) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sunrise.fill").foregroundStyle(Color(hex: 0xF2C25B))
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 18, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(subtitle)
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color(hex: 0xFFE6C7))
            HStack(spacing: 10) {
                if let primary {
                    pill(primary, fill: Color(hex: 0x1A1430))
                }
                pill(secondary, fill: Color.white.opacity(0.2))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, Theme.Spacing.xl)
        .transition(.reveal)
    }

    private func pill(_ action: Action, fill: Color) -> some View {
        Button(action: action.run) {
            Text(action.title)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A small square photo of a show (bundled or downloaded).
private struct ShowArtworkThumb: View {
    let show: Show

    var body: some View {
        Group {
            if let name = show.artworkName, let image = UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = show.imageURL {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.white.opacity(0.06) }
            } else {
                Image("BrandLogo").resizable().scaledToFit().padding(8)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Times and days in the alarm's texts.
enum RadioAlarmFormat {
    /// Monday first, as Czech calendars.
    static let weekOrder = [2, 3, 4, 5, 6, 7, 1]

    static func time(hour: Int, minute: Int) -> String { String(format: "%d:%02d", hour, minute) }

    static func time(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return time(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// "Po–Pá 6:30", "každý den 7:00", "jednou 6:30", "Po, St 6:30".
    static func summary(_ settings: RadioAlarmSettings) -> String {
        "\(days(settings.weekdays)) \(time(hour: settings.hour, minute: settings.minute))"
    }

    static func days(_ weekdays: Set<Int>) -> String {
        switch weekdays {
        case []: L10n.alarmOnce
        case Set(1...7): L10n.alarmEveryDay
        case [2, 3, 4, 5, 6]: L10n.alarmWorkdays
        case [1, 7]: L10n.alarmWeekend
        default: weekOrder.filter(weekdays.contains).map { L10n.shortDayName(weekday: $0) }.joined(separator: ", ")
        }
    }

    /// "Zítra 6:30", "Dnes 6:30", "Po 6:30".
    static func when(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.isDateInToday(date) ? L10n.alarmToday
            : calendar.isDateInTomorrow(date) ? L10n.alarmTomorrow
            : L10n.shortDayName(weekday: calendar.component(.weekday, from: date))
        return "\(day) \(time(date))"
    }
}
