import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(StatsResponse)
        case failed
    }

    @Published private(set) var state: State = .loading

    func loadIfNeeded() {
        guard case .loading = state else { return }
        Task { await load() }
    }

    func refresh() async {
        await load()
    }

    private func load() async {
        do {
            let stats = try await StatisticsService.fetch()
            state = .loaded(stats)
        } catch {
            state = .failed
        }
    }
}
