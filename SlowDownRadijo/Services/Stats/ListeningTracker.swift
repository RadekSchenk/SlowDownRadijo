import Combine
import Foundation
import UIKit

/// Measures how long the radio is actually playing — per calendar day (the
/// listener's own) and per show — and uploads it in small batches.
///
/// * Only `PlaybackState.playing` counts: not connecting, paused, errored.
///   Everything that plays goes through `RadioPlayerService`, so lock screen,
///   headphones and CarPlay are covered as well.
/// * Time is credited every `tickInterval` seconds to the show airing *at
///   that moment* (looked up through `showProvider`), so the server never
///   needs the schedule. A single credit is capped at `maxCreditPerTick`:
///   if the process was suspended or the clock jumped, that gap is dropped
///   rather than guessed.
/// * Unsent time lives in `UserDefaults` and survives relaunches. A batch is
///   sent under a fixed id until the server acknowledges it, so a retry after
///   a lost response can never count the same minutes twice.
/// * Nothing is measured, stored or sent while Settings ▸ "Statistiky
///   poslechu" is off (`StatsConfig.isEnabled`).
@MainActor
final class ListeningTracker {
    static let shared = ListeningTracker()

    /// Used when the schedule has no show for this moment.
    static let unknownShowID = "_"

    /// What the stats screen needs to hear about. `accrued` fires every few
    /// seconds while playing (so "Dnes" ticks up live), `synced` after the
    /// server acknowledged a batch, `deleted` after "Smazat moje statistiky".
    enum Event {
        case accrued, synced, deleted
    }

    let events = PassthroughSubject<Event, Never>()

    private static let storageKey = "stats.listeningQueue"
    private static let tickInterval: TimeInterval = 10
    private static let maxCreditPerTick: TimeInterval = 30
    /// First upload as soon as there's a minute of listening — that's also
    /// what makes someone count towards the listener threshold server-side —
    /// then every few minutes.
    private static let routineThresholdSeconds = 60
    private static let routineFlushGap: TimeInterval = 300
    /// On pause / backgrounding send even small leftovers, but skip
    /// accidental taps so they don't create an anonymous account.
    private static let immediateThresholdSeconds = 10
    private static let immediateFlushGap: TimeInterval = 30
    private static let maxRowsPerBatch = 200

    private struct Batch: Codable {
        let id: UUID
        let rows: [ListeningRow]
    }

    private struct Queue: Codable {
        var pending: [ListeningRow] = []
        var inflight: Batch?
    }

    /// Final class so the background-task expiration handler (which UIKit
    /// declares `@Sendable`) can share the identifier without capturing a `var`.
    private final class BackgroundTask: @unchecked Sendable {
        var id = UIBackgroundTaskIdentifier.invalid
    }

    private var queue: Queue
    private var showProvider: (() -> String?)?

    /// What the player last reported, regardless of the stats preference.
    private var playerIsPlaying = false
    /// Whether time is accruing right now (`playerIsPlaying` and enabled).
    private var isAccruing = false
    private var lastTick: Date?
    /// Sub-second remainder carried between credits so rounding doesn't leak time.
    private var carry: TimeInterval = 0
    private var timer: Timer?
    private var isFlushing = false
    /// The upload in progress, so "delete" can wait for it and "off" can
    /// cancel it.
    private var flushTask: Task<Void, Never>?
    private var lastFlushAttempt = Date.distantPast

    private init() {
        StatsConfig.restorePreferenceIfNeeded()
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(Queue.self, from: data) {
            queue = stored
        } else {
            queue = Queue()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applicationDidEnterBackground() }
        }
    }

    // MARK: - Wiring

    /// `showProvider` returns the id of the show airing right now.
    func configure(showProvider: @escaping () -> String?) {
        self.showProvider = showProvider
    }

    /// Called whenever the player's state changes.
    func update(isPlaying: Bool) {
        accrue()
        playerIsPlaying = isPlaying
        refreshAccruingState()
        if !isAccruing {
            flush(immediate: true)
        }
    }

    /// Everything measured on this phone that the server may not have counted
    /// yet — the in-flight batch plus what's still pending. The stats screen
    /// adds this on top of the server snapshot so numbers are never behind.
    var unsyncedRows: [ListeningRow] {
        (queue.inflight?.rows ?? []) + queue.pending
    }

    /// Called when Settings ▸ "Statistiky poslechu" is switched.
    func enabledPreferenceChanged() {
        StatsConfig.rememberPreference()
        accrue()
        if !StatsConfig.isEnabled {
            // Off means off: nothing measured, nothing unsent is kept, and
            // an upload already under way is cancelled.
            flushTask?.cancel()
            queue = Queue()
            carry = 0
            save()
            events.send(.deleted)
        }
        refreshAccruingState()
    }

    /// "Smazat moje statistiky": drops anything not yet uploaded first (so it
    /// can't resurrect the data), then deletes the server-side rows.
    func deleteAllData() async throws {
        queue = Queue()
        carry = 0
        save()
        // A batch already on its way must land before the delete, or it
        // would recreate the rows right after.
        await flushTask?.value
        try await StatsAPIClient.shared.deleteMyData()
        events.send(.deleted)
    }

    // MARK: - Accrual

    private func refreshAccruingState() {
        let shouldAccrue = playerIsPlaying && StatsConfig.isEnabled
        guard shouldAccrue != isAccruing else { return }
        isAccruing = shouldAccrue
        if shouldAccrue {
            lastTick = Date()
            startTimer()
        } else {
            lastTick = nil
            stopTimer()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // `.common` so ticks keep coming while the user scrolls.
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        accrue()
        flush(immediate: false)
    }

    private func accrue(now: Date = Date()) {
        guard isAccruing, let last = lastTick else { return }
        let delta = min(max(now.timeIntervalSince(last), 0), Self.maxCreditPerTick)
        lastTick = now

        carry += delta
        let whole = Int(carry)
        guard whole > 0 else { return }
        carry -= Double(whole)

        let day = Self.dayString(for: now)
        let showID = showProvider?() ?? Self.unknownShowID
        if let index = queue.pending.firstIndex(where: { $0.day == day && $0.showID == showID }) {
            queue.pending[index].seconds += whole
        } else {
            queue.pending.append(ListeningRow(day: day, showID: showID, seconds: whole))
        }
        save()
        events.send(.accrued)
    }

    /// `yyyy-MM-dd` in the listener's own calendar and time zone — "Dnes"
    /// means today where they are. Explicitly Gregorian so a Buddhist or
    /// Japanese system calendar can't change the format.
    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Upload

    private func applicationDidEnterBackground() {
        accrue()
        flush(immediate: true)
    }

    private func flush(immediate: Bool) {
        guard StatsConfig.isEnabled, !isFlushing else { return }

        let now = Date()
        let minimumGap = immediate ? Self.immediateFlushGap : Self.routineFlushGap
        guard now.timeIntervalSince(lastFlushAttempt) >= minimumGap else { return }

        if queue.inflight == nil {
            let pendingSeconds = queue.pending.reduce(0) { $0 + $1.seconds }
            let threshold = immediate ? Self.immediateThresholdSeconds : Self.routineThresholdSeconds
            guard pendingSeconds >= threshold else { return }

            let rows = Array(queue.pending.prefix(Self.maxRowsPerBatch))
            queue.pending.removeFirst(rows.count)
            queue.inflight = Batch(id: UUID(), rows: rows)
            save()
        }
        guard let batch = queue.inflight else { return }

        isFlushing = true
        lastFlushAttempt = now

        // Lets a request that starts as the app is leaving the foreground finish.
        let background = BackgroundTask()
        background.id = UIApplication.shared.beginBackgroundTask(withName: "stats-flush") {
            UIApplication.shared.endBackgroundTask(background.id)
            background.id = .invalid
        }

        flushTask = Task { [weak self] in
            var batchIsSettled = false
            do {
                try await StatsAPIClient.shared.recordListening(
                    batchID: batch.id,
                    rows: batch.rows,
                    appVersion: Self.appVersion
                )
                batchIsSettled = true
            } catch StatsAPIClient.APIError.rejected(_) {
                // The server will never accept this exact payload; drop it
                // instead of retrying forever.
                batchIsSettled = true
            } catch {
                // Offline, server trouble, session not available yet: the
                // batch stays in the queue and is retried under the same id.
            }
            self?.finishFlush(batchID: batch.id, settled: batchIsSettled)
            if background.id != .invalid {
                UIApplication.shared.endBackgroundTask(background.id)
                background.id = .invalid
            }
        }
    }

    private func finishFlush(batchID: UUID, settled: Bool) {
        isFlushing = false
        flushTask = nil
        guard settled, queue.inflight?.id == batchID else { return }
        queue.inflight = nil
        save()
        events.send(.synced)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
