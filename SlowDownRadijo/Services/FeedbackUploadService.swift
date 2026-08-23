import Foundation

enum FeedbackUploadError: LocalizedError {
    case server(String)
    case transport

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .transport: return "Network error"
        }
    }
}

/// Sends an in-app feedback message to the `send-feedback` Supabase Edge
/// Function, which relays it as an email via Resend. No credentials here:
/// deployed with `--no-verify-jwt`, Resend key stays server-side.
enum FeedbackUploadService {
    static let endpoint = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/functions/v1/send-feedback")!

    static func send(message: String) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Payload(message: message, device: .current()))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedbackUploadError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw FeedbackUploadError.server(serverMessage ?? "Server error")
        }
    }

    private struct Payload: Encodable {
        let message: String
        let device: DeviceInfo
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}
