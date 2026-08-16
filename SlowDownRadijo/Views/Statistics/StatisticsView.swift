import Charts
import SwiftUI

/// Radio-wide stats — collected server-side independent of the app being
/// open (see `backend/supabase/functions/collect-now-playing`). The app is
/// purely a consumer here: no on-device computation, just a read of
/// `get-stats`.
struct StatisticsView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @ObservedObject private var loc = LocalizationManager.shared

    /// Below this many total plays in the window, the repetition
    /// percentage is more "no data yet" than a real number.
    private static let minPlaysForRepetition = 30
    /// Below this many weeks of history, call out that the chart is just
    /// getting started rather than let a nearly-empty chart look broken.
    private static let minWeeksForDiversityChart = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                AppHeaderView()

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tabStatistics)
                        .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L10n.statisticsIntro)
                        .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.lavender)
                }

                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxl)
        case .failed:
            Text(L10n.statisticsLoadFailed)
                .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
                .padding(.vertical, Theme.Spacing.lg)
        case .loaded(let stats):
            diversitySection(stats.diversityWeekly)
            repetitionSection(stats.repetition)
            firstPlaysSection(
                count: stats.firstPlaysWeekCount,
                totalTracks: stats.totalUniqueTracks,
                sample: stats.firstPlaysSample
            )
        }
    }

    // MARK: - Diversity

    private struct DiversityPoint: Identifiable {
        let week: Date
        let kind: String
        let count: Int
        var id: String { "\(week.timeIntervalSince1970)-\(kind)" }
    }

    private func diversitySection(_ weeks: [WeeklyDiversity]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: L10n.diversityTitle, subtitle: L10n.diversitySubtitle)

            if weeks.count < Self.minWeeksForDiversityChart {
                collectingDataNote
            }

            if weeks.isEmpty {
                EmptyView()
            } else {
                Chart(diversityPoints(from: weeks)) { point in
                    BarMark(
                        x: .value("Week", point.week, unit: .weekOfYear),
                        y: .value("Count", point.count)
                    )
                    .foregroundStyle(by: .value("Kind", point.kind))
                }
                .chartForegroundStyleScale([
                    L10n.diversityLegendNew: Theme.sunOrange,
                    L10n.diversityLegendReturning: Theme.lavender.opacity(0.45)
                ])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: max(1, weeks.count / 5))) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .foregroundStyle(Theme.lavender)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline(0.08))
                        AxisValueLabel().foregroundStyle(Theme.lavender)
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: Theme.Spacing.sm)
                .frame(height: 200)
            }
        }
        .padding(Theme.Spacing.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.08), lineWidth: 1)
        )
    }

    private func diversityPoints(from weeks: [WeeklyDiversity]) -> [DiversityPoint] {
        weeks.flatMap { week in
            [
                DiversityPoint(week: week.weekStart, kind: L10n.diversityLegendNew, count: week.firstTimeArtists),
                DiversityPoint(
                    week: week.weekStart,
                    kind: L10n.diversityLegendReturning,
                    count: max(0, week.uniqueArtists - week.firstTimeArtists)
                )
            ]
        }
    }

    // MARK: - Repetition

    private func repetitionSection(_ repetition: RepetitionStats?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(title: L10n.repetitionTitle, subtitle: nil)

            if let repetition, repetition.totalPlays >= Self.minPlaysForRepetition {
                Text(L10n.repetitionDescription(Self.percentFormatter.string(from: NSNumber(value: repetition.repetitionPct)) ?? "–"))
                    .font(Theme.Typography.Manrope.bold(size: 20, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
            } else {
                collectingDataNote
            }
        }
        .padding(Theme.Spacing.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.08), lineWidth: 1)
        )
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // MARK: - First plays

    /// A weekly digest rather than an ever-growing flat list: a headline
    /// count, plus a handful of highlights — resets and refreshes every
    /// week, which is both more attractive to check back on and bounded
    /// (no "just keeps scrolling forever" list to maintain).
    private func firstPlaysSection(count: Int, totalTracks: Int, sample: [FirstPlay]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: L10n.firstPlaysTitle, subtitle: nil)

            if count == 0 {
                Text(L10n.firstPlaysWeekEmpty)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            } else {
                Text(L10n.firstPlaysWeekHeadline(count: count, totalTracks: totalTracks))
                    .font(Theme.Typography.Manrope.bold(size: 20, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)

                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(sample) { entry in
                        FirstPlayRowView(entry: entry)
                    }
                }
            }
        }
    }

    // MARK: - Shared bits

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            }
        }
    }

    private var collectingDataNote: some View {
        Text(L10n.collectingDataNote)
            .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
            .foregroundStyle(Theme.lavender)
    }
}
