import SwiftUI
import UIKit

/// The song line under the show title (Figma "Frame 42"): the song playing
/// now and, swiped sideways, the ones before it — up to ten, each opening
/// its own Spotify search, with how long ago it played under it. After the
/// last one a note says there are no earlier ones here.
///
/// Only songs from the show on air, and only while they follow on from
/// each other: the list stops at the first gap of more than a quarter of
/// an hour, so a swipe never jumps from the song playing now to one from an
/// hour ago. Swiping right goes back in time (the way Spotify's player goes
/// to the previous track). Left alone for 10 seconds it slides back to the
/// song playing now.
///
/// A paging horizontal `ScrollView`, not a drag gesture: the system sorts
/// sideways swipes from the page's vertical scroll (a drag gesture here
/// kept the page from scrolling when the finger started on the song), and
/// a swipe never counts as a tap on the song. The line takes the height of
/// the song showing, so a long earlier song doesn't leave a gap under a
/// short one.
struct SongHistoryLine: View {
    let current: NowPlayingTrack
    /// When the show on air began.
    let showStart: Date?
    /// The schedule, for `TrackTrust`'s placeholder check.
    let shows: [Show]
    /// For the `spotifyOpened` event.
    let showID: String?

    @Environment(\.openURL) private var openURL

    @State private var earlier: [RecentSong] = []
    /// The page showing: 0 is the song playing now, 1…`earlier.count` the
    /// earlier ones, then the end note.
    @State private var visible: Int? = 0
    /// Each page's height, by page.
    @State private var heights: [Int: CGFloat] = [:]

    private var visibleHeight: CGFloat? { heights[visible ?? 0] ?? heights[0] }

    private var pageIDs: [Int] { earlier.isEmpty ? [0] : Array(0...(earlier.count + 1)) }

    var body: some View {
        ScrollView(.horizontal) {
            // Oldest on the left, the song playing now on the right.
            HStack(alignment: .top, spacing: 0) {
                ForEach(pageIDs.reversed(), id: \.self) { id in
                    page(id)
                        .frame(maxWidth: .infinity)
                        // Its own full height, whatever the row allows.
                        .fixedSize(horizontal: false, vertical: true)
                        .containerRelativeFrame(.horizontal)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[id] = $0 }
                }
            }
            .scrollTargetLayout()
            // As tall as the page showing, pages hanging from the top: a
            // taller earlier song (two lines and "před 6 min") would
            // otherwise make the row taller than the frame below, and the
            // scroll view would centre it, pulling the song playing now up
            // towards the host line.
            .frame(height: visibleHeight, alignment: .top)
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visible, anchor: .center)
        .defaultScrollAnchor(.trailing)
        .scrollIndicators(.hidden)
        .scrollDisabled(earlier.isEmpty)
        .frame(height: visibleHeight)
        .animation(.smooth(duration: 0.3), value: visible)
        .task(id: current) {
            showNow()
            earlier = await RecentSongs.load(before: current, since: showStart, shows: shows)
        }
        .task(id: visible) {
            guard (visible ?? 0) != 0 else { return }
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            showNow()
        }
    }

    private func showNow() {
        guard (visible ?? 0) != 0 else { return }
        withAnimation(.smooth(duration: 0.5)) { visible = 0 }
    }

    @ViewBuilder
    private func page(_ id: Int) -> some View {
        if id == 0 {
            songLink(artist: current.artist, title: current.title)
        } else if id <= earlier.count {
            let song = earlier[id - 1]
            VStack(spacing: 4) {
                songLink(artist: song.artist, title: song.title)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(L10n.playedAgo(minutes: Int(context.date.timeIntervalSince(song.playedAt) / 60)))
                        .font(Theme.Typography.Manrope.semibold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.mutedText)
                }
            }
        } else {
            Text(L10n.noEarlierSongs)
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .callout))
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.center)
                .manropeLineHeight(22.4, fontSize: 16)
        }
    }

    /// "Artist – Title" in white with the green Spotify mark after the last
    /// word; text and mark open a Spotify search for artist + title.
    private func songLink(artist: String, title: String) -> some View {
        Button {
            if let url = spotifySearchURL(artist: artist, title: title) {
                Analytics.shared.track(.spotifyOpened(showID: showID))
                openURL(url)
            }
        } label: {
            // The mark is part of the text, so when the song wraps it ends
            // the last line; the word joiner keeps it from wrapping onto a
            // line of its own, and it's lowered 4pt to sit centred on the
            // text.
            Text("\(Text(verbatim: "\(artist) – \(title)\u{2060}"))\(Text(Image(uiImage: Self.spotifyMark).renderingMode(.original)).baselineOffset(-4))")
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .callout))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                // Three lines rather than two: a truncated song would lose
                // the mark at its end.
                .lineLimit(3)
                .manropeLineHeight(22.4, fontSize: 16)
                // A new song playing now crossfades in.
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(artist) – \(title)")
        .accessibilityHint(L10n.spotifyFindAction)
    }

    /// Figma's 19 × 19.6 Spotify mark with the 8pt gap before it built in,
    /// for use inside `Text`.
    private static let spotifyMark: UIImage = {
        guard let icon = UIImage(named: "SpotifyIcon") else { return UIImage() }
        let gap: CGFloat = 8
        let size = CGSize(width: gap + 19, height: 19.623)
        return UIGraphicsImageRenderer(size: size).image { _ in
            icon.draw(in: CGRect(x: gap, y: 0, width: 19, height: 19.623))
        }
    }()
}

struct RecentSong: Equatable {
    let artist: String
    let title: String
    let playedAt: Date
}

/// The songs before the one playing now, from the server's play log
/// (`played_tracks`, written every minute by `collect-now-playing`).
enum RecentSongs {
    static let limit = 10
    /// Two starts further apart than this mean a hole — a long talk, a
    /// mix, or the log missing a stretch — and the list stops there.
    static let maximumGap: TimeInterval = 15 * 60

    static func load(before current: NowPlayingTrack, since showStart: Date?, shows: [Show]) async -> [RecentSong] {
        guard let showStart,
              let rows = try? await RemoteHistoryService.fetchPage(before: nil, windowStart: showStart, limit: 30)
        else { return [] }

        var songs: [RecentSong] = []
        // The start of the entry after the one being looked at.
        var later = Date()
        for (position, row) in rows.enumerated() {
            let playedAt = row.playedAt
            // The newest entry is usually the song playing now.
            if position == 0, TrackTrust.matches(current, artist: row.artist, title: row.title) {
                later = playedAt
                continue
            }
            guard later.timeIntervalSince(playedAt) <= maximumGap else { break }
            later = playedAt
            guard TrackTrust.isRealSong(artist: row.artist, title: row.title, shows: shows) else { continue }
            if let previous = songs.last,
               TrackTrust.normalized(previous.artist) == TrackTrust.normalized(row.artist),
               TrackTrust.normalized(previous.title) == TrackTrust.normalized(row.title) {
                continue
            }
            songs.append(RecentSong(artist: row.artist, title: row.title, playedAt: playedAt))
            if songs.count == limit { break }
        }
        return songs
    }
}
