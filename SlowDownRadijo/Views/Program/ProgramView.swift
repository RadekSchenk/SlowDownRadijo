import SwiftUI

/// Matches the "schedule-screen" Figma redesign: shared masthead, a 28px
/// heading, circular day pills, and full-bleed timeline rows (see
/// `ShowCardView`). Auto-scrolls to the currently-airing show on first
/// appearance so the user doesn't have to hunt for "now" in a long list.
struct ProgramView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedWeekday: Int
    @State private var hasScrolledToLive = false
    @State private var now = Date()

    /// Monday-first order (Po–Ne) for display, independent of `Calendar`'s
    /// Sunday-first `weekday` numbering used internally in `Show` data.
    private static let displayOrder = [2, 3, 4, 5, 6, 7, 1]

    /// Re-evaluates the live show's progress bar periodically — without
    /// this, `ShowCardView` only recomputes progress whenever SwiftUI
    /// happens to re-render for some other reason, so the bar visibly
    /// falls behind the longer the tab stays open.
    private static let progressTicker = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    init(scheduleStore: ScheduleStore) {
        self.scheduleStore = scheduleStore
        _selectedWeekday = State(initialValue: Calendar.current.component(.weekday, from: Date()))
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView()
                .padding(.horizontal, 20)
                // Matches the home screen's header offset exactly (see
                // `HomeView.heroSection`) — fixed 40pt from the true top
                // edge rather than the system safe-area inset, which
                // otherwise put every tab's header at a different distance
                // from the top depending on how much padding its own
                // content wrapper happened to add.
                .padding(.top, 40)

            Text(L10n.tabProgram)
                .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            dayPicker

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let day = scheduleStore.day(for: selectedWeekday) {
                            ForEach(Array(day.shows.enumerated()), id: \.offset) { index, show in
                                ShowCardView(
                                    show: show,
                                    isLive: isCurrentlyLive(show),
                                    progress: scheduleStore.progress(for: show, at: now)
                                )
                                .id(index)
                            }
                        } else {
                            Text(L10n.noProgramForDay)
                                .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                                .foregroundStyle(Theme.lavender)
                                .padding(.top, Theme.Spacing.xl)
                        }
                    }
                }
                .onAppear { scrollToLiveShowIfNeeded(using: proxy) }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .onReceive(Self.progressTicker) { now = $0 }
    }

    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                ForEach(Self.displayOrder, id: \.self) { weekday in
                    let isSelected = selectedWeekday == weekday
                    let isToday = weekday == todayWeekday
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeekday = weekday
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(L10n.shortDayName(weekday: weekday))
                                .font(
                                    isSelected
                                        ? Theme.Typography.Manrope.extraBold(size: 14)
                                        : Theme.Typography.Manrope.semibold(size: 14)
                                )
                                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                                .frame(width: 42, height: 42)
                                .background(
                                    Group {
                                        if isSelected {
                                            Circle().fill(Theme.sunOrange)
                                        } else {
                                            Circle().strokeBorder(Theme.hairline(0.08), lineWidth: 1)
                                        }
                                    }
                                )

                            // Marks today so it stays findable after picking
                            // a different day — you shouldn't have to know
                            // what weekday it actually is to get back to it.
                            // Reserved (just hidden) when not applicable so
                            // every pill has the same height.
                            Circle()
                                .fill(Theme.sunOrange)
                                .frame(width: 5, height: 5)
                                .opacity(isToday && !isSelected ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Theme.background)
    }

    private func isCurrentlyLive(_ show: Show) -> Bool {
        guard selectedWeekday == Calendar.current.component(.weekday, from: Date()) else { return false }
        return scheduleStore.currentShow()?.id == show.id
            && scheduleStore.currentShow()?.start == show.start
    }

    /// Runs once per app session — if the user deliberately scrolls
    /// elsewhere in the list, switching tabs and back shouldn't yank them
    /// back to "now".
    private func scrollToLiveShowIfNeeded(using proxy: ScrollViewProxy) {
        guard !hasScrolledToLive else { return }
        guard let day = scheduleStore.day(for: selectedWeekday),
              let liveShow = scheduleStore.currentShow(),
              let index = day.shows.firstIndex(where: { $0.id == liveShow.id && $0.start == liveShow.start })
        else { return }

        hasScrolledToLive = true
        // A short delay lets the LazyVStack finish its initial layout pass
        // so `scrollTo` has a real anchor to target.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }
}
