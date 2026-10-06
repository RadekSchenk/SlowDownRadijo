import SwiftUI

/// Compact schedule embedded directly on the home screen, below the
/// now-playing card — Figma's "Zapauzovano" frame (node 12294:618..723).
/// Replaces both the earlier "Co hraje dál" list and the standalone
/// Program tab (now hidden behind `FeatureFlags.standaloneProgramTab`,
/// see `RootTabView`) now that full day-by-day browsing lives here.
struct HomeProgramSection: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var loc = LocalizationManager.shared
    /// The show airing right now, if any — splits *today's* list into
    /// "already happened" (tucked behind the disclosure) and "still to
    /// come" (always shown). A day other than today has no "now" to split
    /// on, so it just lists the whole day.
    let currentShow: Show?

    @State private var selectedWeekday: Int
    @State private var isShowingPastShows = false

    init(scheduleStore: ScheduleStore, currentShow: Show?) {
        self.scheduleStore = scheduleStore
        self.currentShow = currentShow
        _selectedWeekday = State(initialValue: Calendar.current.component(.weekday, from: Date()))
    }

    /// Computed fresh on every access, not cached as a `static let` — the
    /// app can stay open across midnight, and a cached value would freeze
    /// "today" at whatever day the process happened to launch on.
    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    /// The next 7 calendar days starting today (not a fixed Monday-first
    /// week) paired with their `Calendar.weekday` — lets the day picker
    /// show real day-of-month numbers while still keying into
    /// `schedule.json`'s weekday-indexed data.
    private var rollingWeek: [(date: Date, weekday: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (date, calendar.component(.weekday, from: date))
        }
    }

    private var isSelectedDayToday: Bool {
        selectedWeekday == todayWeekday
    }

    private var selectedDayShows: [Show] {
        scheduleStore.day(for: selectedWeekday)?.shows ?? []
    }

    /// `currentShow`'s position within `selectedDayShows` — `nil` on any
    /// day but today (no split applies there).
    private var currentShowIndex: Int? {
        guard isSelectedDayToday, let currentShow else { return nil }
        return selectedDayShows.firstIndex { $0.id == currentShow.id && $0.start == currentShow.start }
    }

    private var pastShows: [Show] {
        guard let index = currentShowIndex else { return [] }
        return Array(selectedDayShows[..<index])
    }

    /// Everything after `currentShow` — not `currentShow` itself, which
    /// already has its own card above this section (the hero + progress
    /// bar), so repeating it here would be redundant.
    private var upcomingShows: [Show] {
        guard let index = currentShowIndex else { return selectedDayShows }
        return Array(selectedDayShows[(index + 1)...])
    }

    private var displayedShows: [Show] {
        isShowingPastShows ? pastShows + upcomingShows : upcomingShows
    }

    var body: some View {
        // Figma's "Program — kompaktní seznam" wrapper has *no* gap of its
        // own — only its first child ("Záhlaví programu": heading + day
        // picker + divider) uses the 24pt internal gap. The disclosure and
        // each schedule row carry their own vertical padding instead, so
        // stacking them with an outer `spacing: 24` would double up on
        // that and push everything too far apart.
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(L10n.homeProgramHeading)
                    .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)

                dayPicker

                ListDivider()
            }

            if !pastShows.isEmpty {
                pastShowsDisclosure
                ListDivider()
            }

            if displayedShows.isEmpty {
                Text(L10n.noProgramForDay)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .padding(.vertical, Theme.Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayedShows.enumerated()), id: \.offset) { index, show in
                        compactRow(for: show)
                        if index < displayedShows.count - 1 {
                            ListDivider()
                        }
                    }
                }
            }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 2) {
            ForEach(rollingWeek, id: \.weekday) { entry in
                dayChip(date: entry.date, weekday: entry.weekday)
            }
        }
    }

    private func dayChip(date: Date, weekday: Int) -> some View {
        let isSelected = weekday == selectedWeekday
        let isToday = weekday == todayWeekday
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedWeekday = weekday
                isShowingPastShows = false
            }
        } label: {
            VStack(spacing: 2) {
                // Figma uses two distinct muted purples for the unselected
                // chip, not one — `#a699b8` for the day label, `#807894`
                // for the (lighter-weight) number below it.
                Text(isToday ? L10n.today : L10n.shortDayName(weekday: weekday))
                    .font(
                        isSelected
                            ? Theme.Typography.Manrope.extraBold(size: 12)
                            : Theme.Typography.Manrope.regular(size: 12)
                    )
                    .foregroundStyle(isSelected ? .white : Theme.subtleText)
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(
                        isSelected
                            ? Theme.Typography.Manrope.extraBold(size: 28)
                            : Theme.Typography.Manrope.regular(size: 28)
                    )
                    .foregroundStyle(isSelected ? .white : Color(hex: 0x807894))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(hex: 0x29213F) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var pastShowsDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingPastShows.toggle()
            }
        } label: {
            HStack {
                Text(isShowingPastShows ? L10n.hidePreviousShows : L10n.showPreviousShows(count: pastShows.count))
                    .font(Theme.Typography.Manrope.medium(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
                Spacer(minLength: Theme.Spacing.sm)
                // White, not Theme.mutedText — confirmed by
                // rendering the Figma icon node in isolation, since this
                // one exports as a flattened image with no readable color
                // in the design-context output.
                Image(systemName: "chevron.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isShowingPastShows ? 180 : 0))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func compactRow(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(show.start)
                .font(Theme.Typography.Manrope.regular(size: 30, relativeTo: .title))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(Theme.Typography.Manrope.extraBold(size: 21, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)

                if let hostName = show.hostName {
                    Text(hostName)
                        .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.subtleText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

}
