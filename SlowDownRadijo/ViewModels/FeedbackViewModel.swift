import Foundation

enum FeedbackState: Equatable {
    case idle
    case sending
    case sent
    case failed
}

@MainActor
final class FeedbackViewModel: ObservableObject {
    @Published var message = ""
    @Published private(set) var state: FeedbackState = .idle

    private static let minLength = 3

    var canSubmit: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minLength && state != .sending
    }

    func submit() {
        guard canSubmit else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .sending

        Task {
            do {
                try await FeedbackUploadService.send(message: text)
                message = ""
                state = .sent
            } catch {
                state = .failed
            }
        }
    }

    /// Lets the user try again after a failure, or start a fresh message
    /// after a successful send (see `SettingsView`).
    func reset() {
        state = .idle
    }
}
