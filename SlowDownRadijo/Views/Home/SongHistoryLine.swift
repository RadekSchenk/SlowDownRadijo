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
/// hour ago. Dragging right goes back in time (the way Spotify's player
/// goes to the previous track); left of the song playing now there's
/// nothing. Left alone for 10 seconds it slides back to the song playing
/// now. Only a sideways drag moves it, so it doesn't fight the page's
/// vertical scroll. With Reduce Motion the songs crossfade.
struct SongHistoryLine: View {
    let current: NowPlayingTrack
    /// When the show on air began.
    let showStart: Date?
    /// The schedule, for `TrackTrust`'s placeholder check.
    let shows: [Show]
    /// For the `spotifyOpened` event.
    let showID: String?

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var earlier: [RecentSong] = []
    /// 0 is the song playing now, 1…`earlier.count` earlier ones, then the
    /// end note.
    @State private var index = 0
    @State private var dragOffset: CGFloat = 0
    /// Decided on a drag's first movement: sideways drags browse, others
    /// are left to the page.
    @State private var isSidewaysDrag: Bool?
    /// Which way the last move went, for the push transition.
    @State private var goingBack = true
    /// Bumped on every touch, restarting the return-to-now countdown.
    @State private var interactions = 0
    /// True from a drag's first movement until just after it ends. The
    /// finger lifts over the song it dragged, which would count as a tap
    /// on it and open Spotify; a drag is never a tap.
    @State private var isDragging = false

    private var pageCount: Int { earlier.isEmpty ? 1 : earlier.count + 2 }

    var body: some View {
        ZStack {
            page(at: index)
                .id(index)
                .transition(reduceMotion ? .opacity : .push(from: goingBack ? .leading : .trailing))
        }
        .frame(maxWidth: .infinity)
        .offset(x: reduceMotion ? 0 : dragOffset)
        .opacity(1 - min(abs(dragOffset) / 300, 0.4))
        .contentShape(Rectangle())
        .simultaneousGesture(drag)
        .task(id: current) {
            if index != 0 { go(to: 0) }
            earlier = await RecentSongs.load(before: current, since: showStart, shows: shows)
        }
        .task(id: interactions) {
            guard index != 0 else { return }
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, index != 0 else { return }
            go(to: 0)
        }
    }

    @ViewBuilder
    private func page(at index: Int) -> some View {
        if index == 0 {
            songLink(artist: current.artist, title: current.title)
        } else if index <= earlier.count {
            let song = earlier[index - 1]
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
                .accessibilityAdjustableAction(adjust)
        }
    }

    /// "Artist – Title" in white with the green Spotify mark after the last
    /// word; text and mark open a Spotify search for artist + title.
    private func songLink(artist: String, title: String) -> some View {
        Button {
            guard !isDragging else { return }
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
        // VoiceOver: swipe up / down to step through the songs.
        .accessibilityAdjustableAction(adjust)
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .decrement: go(to: min(index + 1, pageCount - 1))
        case .increment: go(to: max(index - 1, 0))
        @unknown default: break
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if isSidewaysDrag == nil {
                    isSidewaysDrag = abs(value.translation.width) > abs(value.translation.height)
                    isDragging = true
                    interactions += 1
                }
                guard isSidewaysDrag == true, pageCount > 1 else { return }
                let width = value.translation.width
                // Past either end it gives a little, then pulls back.
                let pastEnd = (width > 0 && index == pageCount - 1) || (width < 0 && index == 0)
                dragOffset = pastEnd ? width / 4 : width
            }
            .onEnded { value in
                defer {
                    isSidewaysDrag = nil
                    // After the button has seen the lift (it may come
                    // either side of this).
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        isDragging = false
                    }
                }
                guard isSidewaysDrag == true, pageCount > 1 else { return }
                let width = value.predictedEndTranslation.width
                if width > 60 {
                    go(to: min(index + 1, pageCount - 1))
                } else if width < -60 {
                    go(to: max(index - 1, 0))
                } else {
                    go(to: index)
                }
            }
    }

    private func go(to target: Int) {
        goingBack = target > index
        interactions += 1
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.35, bounce: 0.15)) {
            index = target
            dragOffset = 0
        }
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
