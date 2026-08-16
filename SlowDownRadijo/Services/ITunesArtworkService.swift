import Foundation

/// Looks up album artwork for a track via Apple's public iTunes Search API
/// (`itunes.apple.com/search`) — no API key, no account, independent of
/// slowdownradijo.cz. Used to give locally-observed history entries (see
/// `PlayHistoryStore`) real per-track artwork, since our own ICY-metadata
/// log only has artist/title, not images.
actor ITunesArtworkService {
    static let shared = ITunesArtworkService()

    private struct LookupResult {
        let artworkURL: URL?
        let previewURL: URL?
    }

    private var cache: [String: LookupResult] = [:]

    func artworkURL(artist: String, title: String) async -> URL? {
        await lookupResult(artist: artist, title: title).artworkURL
    }

    /// The 30-second AAC preview clip iTunes returns alongside the search
    /// result — a studio-recording preview of the song, not a recording of
    /// the actual broadcast moment (the station only logs artist/title via
    /// ICY metadata; see `PlayHistoryStore`, which never records audio).
    /// Used for the quick-listen button on "Co hrálo"/Favorites rows.
    func previewURL(artist: String, title: String) async -> URL? {
        await lookupResult(artist: artist, title: title).previewURL
    }

    private func lookupResult(artist: String, title: String) async -> LookupResult {
        let key = "\(artist)|\(title)".lowercased()
        if let cached = cache[key] {
            return cached
        }

        let result = await lookup(artist: artist, title: title)
        // Only cache genuine matches. A completely empty result can mean
        // "not in iTunes' catalog" (permanent), but it can just as easily
        // mean a transient network hiccup or the search API rate-limiting a
        // burst of concurrent lookups (see
        // `HistoryViewModel.resolveArtworkForRemoteTracks`) — caching that
        // forever would permanently block both artwork *and* the preview
        // button for a track that would have resolved fine on a retry.
        if result.artworkURL != nil || result.previewURL != nil {
            cache[key] = result
        }
        return result
    }

    private func lookup(artist: String, title: String) async -> LookupResult {
        guard let url = searchURL(artist: artist, title: title) else { return LookupResult(artworkURL: nil, previewURL: nil) }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else {
                return LookupResult(artworkURL: nil, previewURL: nil)
            }

            // iTunes' text search is fuzzy — it very rarely returns zero
            // results, even for station-only content (jingles, promos, DJ
            // mix blocks) that isn't a real catalogable song. Left
            // unchecked this surfaces confidently-wrong matches (e.g.
            // searching "SLOWDOWN PROMO" returns King Promise's unrelated
            // song "Slow Down"). Requiring the returned track name to share
            // at least one real word with what we searched for rejects
            // those false positives while real matches — which are always
            // at least near-identical — sail through.
            guard let trackName = first["trackName"] as? String,
                  Self.sharesSignificantWord(searched: title, result: trackName) else {
                return LookupResult(artworkURL: nil, previewURL: nil)
            }

            var artwork: URL?
            if let artworkString = first["artworkUrl100"] as? String {
                // Request a bigger image than the default 100x100 thumbnail.
                let upscaled = artworkString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                artwork = URL(string: upscaled)
            }
            let preview = (first["previewUrl"] as? String).flatMap(URL.init(string:))
            return LookupResult(artworkURL: artwork, previewURL: preview)
        } catch {
            return LookupResult(artworkURL: nil, previewURL: nil)
        }
    }

    private func searchURL(artist: String, title: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        return components?.url
    }

    private static func sharesSignificantWord(searched: String, result: String) -> Bool {
        let searchedWords = significantWords(in: searched)
        // Nothing meaningful to compare (e.g. a one/two-letter title) —
        // don't block on a check that can't say anything useful.
        guard !searchedWords.isEmpty else { return true }
        return !searchedWords.isDisjoint(with: significantWords(in: result))
    }

    private static func significantWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )
    }
}
