import Foundation

enum VoiceMessageUploadError: LocalizedError {
    case server(String)
    case transport

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .transport: return "Network error"
        }
    }
}

/// Uploads a recorded voice message to the `send-voice-message` Supabase
/// Edge Function, which relays it as an email attachment via Resend — see
/// `backend/README.md`. No credentials live here: the endpoint is deployed
/// with `--no-verify-jwt` (public, no auth token needed), and the Resend
/// API key stays server-side.
enum VoiceMessageUploadService {
    static let endpoint = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co/functions/v1/send-voice-message")!

    static func upload(fileURL: URL) async throws {
        let boundary = UUID().uuidString
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try body(for: fileURL, boundary: boundary)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VoiceMessageUploadError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw VoiceMessageUploadError.server(serverMessage ?? "Server error")
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    private static func body(for fileURL: URL, boundary: String) throws -> Data {
        let audioData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
