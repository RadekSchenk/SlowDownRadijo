import Foundation

/// A single article from slowdownradijo.cz's own "Novinky" feed — read
/// directly from the WordPress REST API (`/wp/v2/posts`), the same
/// content the website shows. Deliberately doesn't mirror the site's own
/// styling (categories, likes, ratings, sharing, comments) — those are
/// WordPress-theme chrome, not something this app's reader needs; just
/// the publish date, title, and content (including images/embeds).
struct NewsPost: Decodable, Identifiable {
    let id: Int
    let dateGMTString: String
    let titleRendered: String
    let contentRendered: String
    let embedded: Embedded?

    enum CodingKeys: String, CodingKey {
        case id
        case dateGMTString = "date_gmt"
        case title, content
        case embedded = "_embedded"
    }

    private enum RenderedKeys: String, CodingKey { case rendered }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        dateGMTString = try container.decode(String.self, forKey: .dateGMTString)

        let titleContainer = try container.nestedContainer(keyedBy: RenderedKeys.self, forKey: .title)
        titleRendered = try titleContainer.decode(String.self, forKey: .rendered)

        let contentContainer = try container.nestedContainer(keyedBy: RenderedKeys.self, forKey: .content)
        contentRendered = try contentContainer.decode(String.self, forKey: .rendered)

        embedded = try container.decodeIfPresent(Embedded.self, forKey: .embedded)
    }

    struct Embedded: Decodable {
        let featuredMedia: [FeaturedMedia]?
        enum CodingKeys: String, CodingKey { case featuredMedia = "wp:featuredmedia" }
    }

    struct FeaturedMedia: Decodable {
        let sourceURL: URL?
        enum CodingKeys: String, CodingKey { case sourceURL = "source_url" }
    }

    var title: String { titleRendered.htmlStripped }
    var featuredImageURL: URL? { embedded?.featuredMedia?.first?.sourceURL }

    /// `date_gmt` has no timezone suffix (WordPress convention) — treat it
    /// as UTC and let the device localize it for display.
    var date: Date {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = withFraction.date(from: dateGMTString + "Z") { return parsed }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: dateGMTString + "Z") ?? .distantPast
    }

    var contentBlocks: [NewsContentBlock] {
        NewsContentParser.parse(contentRendered)
    }
}
