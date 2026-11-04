import WidgetKit

/// Widgets run in their own process on a system-managed refresh budget
/// (typically tens of minutes between reloads, not continuous) and can't
/// drive the live audio stream — this only ever shows "what's on right
/// now" for someone to glance at, then opens the app on tap.
struct NowPlayingProvider: TimelineProvider {
    private let scheduleStore = ScheduleStore()

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), show: scheduleStore.currentShow(), latestArtist: nil, latestTitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let now = Date()
        let show = scheduleStore.currentShow(at: now)

        // Widget gallery previews don't need a real network round trip.
        guard !context.isPreview else {
            completion(NowPlayingEntry(date: now, show: show, latestArtist: nil, latestTitle: nil))
            return
        }

        Task {
            let track = await verifiedLatestTrack(now: now, show: show)
            completion(NowPlayingEntry(date: now, show: show, latestArtist: track?.artist, latestTitle: track?.title))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        Task {
            let now = Date()
            let show = scheduleStore.currentShow(at: now)
            let track = await verifiedLatestTrack(now: now, show: show)
            let entry = NowPlayingEntry(date: now, show: show, latestArtist: track?.artist, latestTitle: track?.title)

            // Reload at most every 15 minutes, or right when the current
            // show ends if that comes sooner — keeps the show name flipping
            // on time without burning through the refresh budget.
            var reloadDate = now.addingTimeInterval(15 * 60)
            if let show, let endDate = scheduleStore.endDate(for: show, relativeTo: now),
               endDate > now, endDate < reloadDate {
                reloadDate = endDate
            }
            // A song shown is gone once it can't be playing any more.
            if let track {
                let stale = track.playedAt.addingTimeInterval(TrackTrust.maximumAge)
                if stale > now, stale < reloadDate { reloadDate = stale }
            }

            completion(Timeline(entries: [entry], policy: .after(reloadDate)))
        }
    }

    /// The latest song from the server, only when the app would show it too
    /// (`TrackTrust`): no station noise or show placeholders, started within
    /// the last few minutes, and — in a hosted show — after the show began.
    private func verifiedLatestTrack(now: Date, show: Show?) async -> RemotePlayedTrack? {
        guard let track = await LatestTrackService.fetchLatest() else { return nil }
        let shows = scheduleStore.days.flatMap(\.shows)
        guard TrackTrust.isRealSong(artist: track.artist, title: track.title, shows: shows) else { return nil }
        let showStart = show?.hostName == nil ? nil : show.flatMap { scheduleStore.startDate(for: $0, relativeTo: now) }
        guard TrackTrust.isCurrent(start: track.playedAt, now: now, showStart: showStart) else { return nil }
        return track
    }
}
