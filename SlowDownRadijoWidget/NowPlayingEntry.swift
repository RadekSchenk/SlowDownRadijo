import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let show: Show?
    let latestArtist: String?
    let latestTitle: String?
}
