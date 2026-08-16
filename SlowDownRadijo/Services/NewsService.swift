import Foundation

/// Reads slowdownradijo.cz's own "Novinky" (blog) posts directly from its
/// public WordPress REST API — no backend of ours involved, so the
/// station keeps managing content exactly where they already do, in
/// WordPress, with nothing new for us to administer.
enum NewsService {
    private static let baseURL = URL(string: "https://slowdownradijo.cz/wp-json/wp/v2/posts")!

    static func fetchRecent(limit: Int = 30) async throws -> [NewsPost] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "_embed", value: "true"),
            URLQueryItem(name: "per_page", value: "\(limit)"),
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([NewsPost].self, from: data)
    }
}
