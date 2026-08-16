import Foundation

@MainActor
final class NewsViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([NewsPost])
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
            let posts = try await NewsService.fetchRecent()
            state = .loaded(posts)
        } catch {
            state = .failed
        }
    }
}
