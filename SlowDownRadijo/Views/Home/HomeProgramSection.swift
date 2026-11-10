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
    /// The selected day's pill slides between days (library P16 — tabs with
    /// a sliding active indicator).
    @Namespace private var dayPill
    @State private var isShowingPastShows = false

    init(scheduleStore: ScheduleStore, currentShow: Show?) {
        self.scheduleStore = scheduleStore
        self.currentShow = currentShow
        _selectedWeekday = State(initialValue: ScheduleStore.stationCalendar.component(.weekday, from: Date()))
    }

    /// Computed fresh on every access, not cached as a `static let` — the
    /// app can stay open across midnight, and a cached value would freeze
    /// "today" at whatever day the process happened to launch on.
    private var todayWeekday: Int {
        ScheduleStore.stationCalendar.component(.weekday, from: Date())
    }

    /// The next 7 calendar days starting today (not a fixed Monday-first
    /// week) paired with their `Calendar.weekday` — lets the day picker
    /// show real day-of-month numbers while still keying into
    /// `schedule.json`'s weekday-indexed data.
    private var rollingWeek: [(date: Date, weekday: Int)] {
        let calendar = ScheduleStore.stationCalendar
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
                // The home page's type scale: see `StatsHomeBlock`.
                Text(L10n.homeProgramHeading)
                    .font(Theme.Typography.Heading.section)
                    .foregroundStyle(Theme.textPrimary)

                dayPicker

                ListDivider()
            }
            .movesWithScroll()

            if !pastShows.isEmpty {
                VStack(spacing: 0) {
                    pastShowsDisclosure
                    ListDivider()
                }
                .movesWithScroll()
            }

            if displayedShows.isEmpty {
                Text(L10n.noProgramForDay)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
                    .padding(.vertical, Theme.Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayedShows.enumerated()), id: \.offset) { index, show in
                        // Each row with its divider, so they move as one.
                        VStack(spacing: 0) {
                            compactRow(for: show)
                            if index < displayedShows.count - 1 {
                                ListDivider()
                            }
                        }
                        .movesWithScroll()
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
            withAnimation(Motion.tabsSliding) {
                selectedWeekday = weekday
                isShowingPastShows = false
            }
        } label: {
            VStack(spacing: 2) {
                // Unselected: `#a699b8` Regular label, `#807894` Light number.
                Text(isToday ? L10n.today : L10n.shortDayName(weekday: weekday))
                    .font(
                        isSelected
                            ? Theme.Typography.Manrope.extraBold(size: 12)
                            : Theme.Typography.Manrope.regular(size: 12)
                    )
                    .foregroundStyle(isSelected ? .white : Theme.subtleText)
                Text("\(ScheduleStore.stationCalendar.component(.day, from: date))")
                    .font(
                        isSelected
                            ? Theme.Typography.Manrope.extraBold(size: 22)
                            : Theme.Typography.Manrope.light(size: 22)
                    )
                    .foregroundStyle(isSelected ? .white : Color(hex: 0x807894))
                    .manropeLineHeight(28, fontSize: 22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0x29213F))
                        .matchedGeometryEffect(id: "dayPill", in: dayPill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var pastShowsDisclosure: some View {
        Button {
            // Library P21 — accordion: 250ms smooth-out for panel and chevron.
            withAnimation(Motion.accordion) {
                isShowingPastShows.toggle()
            }
        } label: {
            HStack {
                PopNumberText(
                    text: isShowingPastShows ? L10n.hidePreviousShows : L10n.showPreviousShows(count: pastShows.count),
                    font: Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline),
                    color: Theme.textPrimary
                )
                .lineLimit(1)
                Spacer(minLength: Theme.Spacing.sm)
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

    /// A show in the list (Figma "Položka programu"): its square photo on
    /// the left — the home cover's look at list size (80pt, 8pt corners,
    /// the cover's 96 / 10 in proportion) — and, 14pt to its right as from
    /// the cover to the show title above, the start time with the reminder
    /// bell at its end, the title and the host. The photo runs from the top
    /// of the time to about the bottom of the host line, so its edges line
    /// up with the text beside it. The description runs edge to edge
    /// underneath, 12pt below the photo.
    private func compactRow(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ShowArtworkView(show: show, size: Self.thumbnailSize, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(show.start)
                            .font(Theme.Typography.Manrope.light(size: 22, relativeTo: .title3))
                            .foregroundStyle(Theme.textPrimary)
                            .manropeLineHeight(28, fontSize: 22)
                        Spacer(minLength: Theme.Spacing.sm)
                        ReminderBellButton(show: show)
                            // Optically flush with the row's right edge, and
                            // no taller than the time it sits beside.
                            .padding(.trailing, -10)
                            .frame(height: 28)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(show.displayTitle)
                            .font(Theme.Typography.Heading.item)
                            .foregroundStyle(Theme.textPrimary)
                            .manropeLineHeight(22, fontSize: 17)

                        if let hostName = show.hostName {
                            Text(hostName)
                                .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let summary = show.localizedSummary {
                Text(summary)
                    .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)
                    .manropeLineHeight(20, fontSize: 14)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 16)
    }

    private static let thumbnailSize: CGFloat = 80

}
