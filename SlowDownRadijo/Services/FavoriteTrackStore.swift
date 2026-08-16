import Foundation
import SwiftData
import UIKit

/// Local, on-device store of everything the user has hearted. Doubles as
/// its own "view model": unlike `PlayHistoryStore`, favorites don't need
/// pagination or a local/remote merge, so there's no separate
/// `FavoritesViewModel` — this is small enough to publish state directly.
@MainActor
final class FavoriteTrackStore: ObservableObject {
    /// Every current favorite, newest-added first.
    @Published private(set) var favorites: [FavoriteTrack] = []
    /// Mirrors `favorites` as normalized keys, so heart buttons throughout
    /// the app (e.g. `HistoryRowView`) can check membership without a
    /// linear scan per row per render.
    @Published private(set) var favoritedKeys: Set<String> = []

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() {
        do {
            // An explicit, distinct store file — `ModelContainer(for:)`
            // without one defaults every SwiftData container in the app to
            // the same `default.store` file regardless of which type is
            // passed in, which collides with `PlayHistoryStore`'s own
            // container (a different, incompatible schema) sharing that
            // same default file.
            let url = URL.applicationSupportDirectory.appending(path: "FavoriteTracks.sqlite")
            let configuration = ModelConfiguration(url: url)
            container = try ModelContainer(for: FavoriteTrack.self, configurations: configuration)
        } catch {
            fatalError("Failed to create FavoriteTrackStore container: \(error)")
        }
        reload()
    }

    func isFavorite(artist: String, title: String) -> Bool {
        favoritedKeys.contains(FavoriteTrack.normalize(artist: artist, title: title))
    }

    /// Adds the track if it isn't already favorited, removes it if it is.
    /// The haptic tap isn't just polish — it's an unambiguous signal (felt
    /// even if the button's own label somehow fails to visually update)
    /// that the tap actually reached this code.
    func toggle(artist: String, title: String, artworkURL: URL?) {
        if isFavorite(artist: artist, title: title) {
            remove(artist: artist, title: title)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            add(artist: artist, title: title, artworkURL: artworkURL)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func remove(_ favorite: FavoriteTrack) {
        context.delete(favorite)
        try? context.save()
        reload()
    }

    private func add(artist: String, title: String, artworkURL: URL?) {
        guard !isFavorite(artist: artist, title: title) else { return }
        context.insert(FavoriteTrack(artist: artist, title: title, artworkURL: artworkURL))
        try? context.save()
        reload()
    }

    private func remove(artist: String, title: String) {
        let key = FavoriteTrack.normalize(artist: artist, title: title)
        let descriptor = FetchDescriptor<FavoriteTrack>(predicate: #Predicate { $0.normalizedKey == key })
        guard let match = try? context.fetch(descriptor).first else { return }
        context.delete(match)
        try? context.save()
        reload()
    }

    private func reload() {
        let descriptor = FetchDescriptor<FavoriteTrack>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        favorites = (try? context.fetch(descriptor)) ?? []
        favoritedKeys = Set(favorites.map(\.normalizedKey))
    }
}
