import Foundation

/// The weekly programme as slowdownradijo.cz shows it. The station edits
/// the week on the web for special broadcasts (a live show from a festival
/// over a weekend, say), so the app follows the web rather than the
/// programme bundled with it (`schedule.json`).
///
/// Two requests: the week (`/proradio/v1/schedule`: per day, show post ids
/// with start and end times) and those shows (`/wp/v2/shows`: titles and
/// photos). A show the app knows (`Show.webID`, or the same name) keeps
/// everything bundled for it — host, photo, descriptions, its id for the
/// listening stats and reminders — with the web's times. A show it doesn't
/// know, a special, gets its title and photo from the web, no host, and no
/// description unless the web has one. The web leaves the station's
/// rotation out; those hours are "The Best of Slow Down", as on air.
enum WebScheduleService {
    static let scheduleURL = URL(string: "https://slowdownradijo.cz/wp-json/proradio/v1/schedule")!

    /// The id of the rotation that fills the hours the web leaves empty.
    static let rotationID = "the-best-of-slow-down"

    enum Failure: Error {
        case badResponse
        case incomplete
    }

    /// The week from the web, built on `catalog` (the bundled shows).
    static func fetch(catalog: [Show], session: URLSession = .shared) async throws -> [ScheduleDay] {
        let week = try await get(WeekResponse.self, from: scheduleURL, session: session)
        let ids = Set(week.posts.flatMap { $0.shows.flatMap(\.showIDs) })
        let shows = ids.isEmpty ? [] : try await get([WebShow].self, from: showsURL(ids: ids), session: session)
        return try build(week: week, shows: shows, catalog: catalog)
    }

    static func showsURL(ids: Set<Int>) -> URL {
        var components = URLComponents(string: "https://slowdownradijo.cz/wp-json/wp/v2/shows")!
        components.queryItems = [
            URLQueryItem(name: "include", value: ids.sorted().map(String.init).joined(separator: ",")),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"),
            URLQueryItem(name: "_fields", value: "id,slug,title,excerpt,_links,_embedded"),
        ]
        return components.url!
    }

    private static func get<T: Decodable>(_ type: T.Type, from url: URL, session: URLSession) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Building the week

    static func build(week: WeekResponse, shows: [WebShow], catalog: [Show]) throws -> [ScheduleDay] {
        let webShows = Dictionary(shows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let byWebID = Dictionary(catalog.compactMap { show in show.webID.map { ($0, show) } },
                                 uniquingKeysWith: { first, _ in first })
        let byName = Dictionary(catalog.map { (normalized($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        guard let rotation = catalog.first(where: { $0.id == rotationID }) else { throw Failure.incomplete }

        func show(for webID: Int) -> Show? {
            if let known = byWebID[webID] { return known }
            guard let web = webShows[webID] else { return nil }
            if let known = byName[normalized(web.title)] { return known }
            let summary = web.excerpt.flatMap { $0.isEmpty ? nil : $0 }
            return Show(
                id: showID(slug: web.slug, webID: webID),
                name: web.title,
                start: "",
                end: "",
                imageURL: web.imageURL,
                summary: summary,
                webID: webID
            )
        }

        var days: [Int: ScheduleDay] = [:]
        for post in week.posts {
            guard let weekday = post.weekday, days[weekday] == nil else { continue }
            let slots = post.shows.compactMap { slot -> (show: Show, start: Int, end: Int)? in
                guard let id = slot.showIDs.first, let found = show(for: id),
                      let start = minutes(slot.start), let rawEnd = minutes(slot.end) else { return nil }
                // "00:00" (or an end before the start) closes the day.
                let end = rawEnd <= start ? 1440 : min(rawEnd, 1440)
                return (found, start, end)
            }
            .sorted { $0.start < $1.start }

            var result: [Show] = []
            var cursor = 0
            for slot in slots {
                let start = max(slot.start, cursor)
                guard start < slot.end else { continue }
                if start > cursor { result.append(rotation.at(cursor, start)) }
                result.append(slot.show.at(start, slot.end))
                cursor = slot.end
            }
            if cursor < 1440 { result.append(rotation.at(cursor, 1440)) }

            days[weekday] = ScheduleDay(weekday: weekday, dayName: post.title, shows: result)
        }

        // Every day of the week, or the programme stays as it was.
        guard days.count == 7 else { throw Failure.incomplete }
        return days.values.sorted { $0.weekday < $1.weekday }
    }

    /// The id a special goes by in the listening stats and reminders: its
    /// web slug, in the letters the stats server takes (`[a-z0-9-]`).
    static func showID(slug: String, webID: Int) -> String {
        let folded = (slug.removingPercentEncoding ?? slug)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            .lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        let dashed = String(folded.map { allowed.contains($0) ? $0 : "-" })
        let id = dashed.split(separator: "-").joined(separator: "-")
        return id.isEmpty ? "web-\(webID)" : id
    }

    private static func minutes(_ time: String) -> Int? {
        let parts = time.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    static func time(_ minutes: Int) -> String {
        let value = minutes % 1440
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    /// Names compared without case, accents or odd spaces ("cube positive"
    /// comes from the web with a no-break space).
    static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Responses

    struct WeekResponse: Decodable {
        let posts: [DayPost]
    }

    struct DayPost: Decodable {
        let title: String
        let slug: String
        let order: Int?
        let shows: [Slot]

        private enum CodingKeys: String, CodingKey {
            case title = "post_title", slug = "post_name", order = "menu_order", shows
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = (try? container.decode(String.self, forKey: .title)) ?? ""
            slug = (try? container.decode(String.self, forKey: .slug)) ?? ""
            order = try? container.decode(Int.self, forKey: .order)
            // A day the station emptied comes without its list (or `false`).
            shows = (try? container.decode([Slot].self, forKey: .shows)) ?? []
        }

        /// `Calendar` weekday (1 = Sunday): from the day's Czech title,
        /// else its English slug ("monday-2"), else its place in the week
        /// (1 = Monday).
        var weekday: Int? {
            let czech = ["nedele": 1, "pondeli": 2, "utery": 3, "streda": 4, "ctvrtek": 5, "patek": 6, "sobota": 7]
            if let day = czech[WebScheduleService.normalized(title)] { return day }
            let english = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
            if let day = english.first(where: { slug.lowercased().hasPrefix($0.key) })?.value { return day }
            if let order, (1...7).contains(order) { return order % 7 + 1 }
            return nil
        }
    }

    struct Slot: Decodable {
        let showIDs: [Int]
        let start: String
        let end: String

        private enum CodingKeys: String, CodingKey {
            case showIDs = "show_id", start = "show_time", end = "show_time_end"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            start = (try? container.decode(String.self, forKey: .start)) ?? ""
            end = (try? container.decode(String.self, forKey: .end)) ?? ""
            // ["13920"] on the web today; a plain string or number also does.
            if let strings = try? container.decode([String].self, forKey: .showIDs) {
                showIDs = strings.compactMap { Int($0) }
            } else if let numbers = try? container.decode([Int].self, forKey: .showIDs) {
                showIDs = numbers
            } else if let string = try? container.decode(String.self, forKey: .showIDs), let id = Int(string) {
                showIDs = [id]
            } else if let number = try? container.decode(Int.self, forKey: .showIDs) {
                showIDs = [number]
            } else {
                showIDs = []
            }
        }
    }

    struct WebShow: Decodable {
        let id: Int
        let slug: String
        let title: String
        let excerpt: String?
        let imageURL: URL?

        private struct Rendered: Decodable { let rendered: String }
        private struct Embedded: Decodable {
            let media: [Media]?
            private enum CodingKeys: String, CodingKey { case media = "wp:featuredmedia" }
        }
        private struct Media: Decodable {
            let sourceURL: String?
            private enum CodingKeys: String, CodingKey { case sourceURL = "source_url" }
        }
        private enum CodingKeys: String, CodingKey {
            case id, slug, title, excerpt, embedded = "_embedded"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            slug = (try? container.decode(String.self, forKey: .slug)) ?? ""
            let rawTitle = (try? container.decode(Rendered.self, forKey: .title))?.rendered ?? ""
            title = HTMLText.plain(rawTitle)
            let rawExcerpt = (try? container.decode(Rendered.self, forKey: .excerpt))?.rendered
            excerpt = rawExcerpt.map { HTMLText.plain($0) }
            let source = (try? container.decode(Embedded.self, forKey: .embedded))?.media?.first?.sourceURL
            imageURL = source.flatMap(URL.init(string:))
        }
    }
}

private extension Show {
    /// The same show in another slot.
    func at(_ start: Int, _ end: Int) -> Show {
        Show(
            id: id, name: name,
            start: WebScheduleService.time(start), end: WebScheduleService.time(end),
            imageURL: imageURL, language: language,
            hostName: hostName, hostImageName: hostImageName, artworkName: artworkName,
            title: title, summary: summary, summaryEn: summaryEn, webID: webID
        )
    }
}

/// WordPress's rendered HTML as plain text: tags out, entities decoded,
/// the excerpt's "[…]" dropped. Enough for titles and short excerpts.
enum HTMLText {
    static func plain(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "[…]", with: "…")
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let named: [String: String] = [
        "amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "lsquo": "‘", "rsquo": "’",
        "sbquo": "‚", "ldquo": "“", "rdquo": "”", "bdquo": "„",
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let afterAmp = rest.index(after: amp)
            guard let semicolon = rest[afterAmp...].prefix(10).firstIndex(of: ";") else {
                result += "&"
                rest = rest[afterAmp...]
                continue
            }
            let entity = String(rest[afterAmp..<semicolon])
            if let decoded = decode(entity) {
                result += decoded
            } else {
                result += rest[amp...semicolon]
            }
            rest = rest[rest.index(after: semicolon)...]
        }
        return result + rest
    }

    private static func decode(_ entity: String) -> String? {
        if entity.hasPrefix("#") {
            let digits = entity.dropFirst()
            let value = digits.lowercased().hasPrefix("x")
                ? UInt32(digits.dropFirst(), radix: 16)
                : UInt32(digits)
            return value.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
        return named[entity]
    }
}
