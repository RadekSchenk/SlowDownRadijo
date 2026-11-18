import Combine
import Foundation
import Supabase
import UIKit

/// The listeners' chat (`docs/chat-concept.md`): one stream for the whole
/// radio, read by anyone, written by signed-in listeners.
///
/// Loads the last week (`historyDays`) once, then follows `chat_messages`
/// over Realtime while the app is in the foreground — new, deleted, pinned
/// and renamed messages. Coming back to the foreground reloads, so nothing
/// sent meanwhile is missed.
@MainActor
final class ChatService: ObservableObject {
    static let shared = ChatService()

    /// Oldest first.
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var outgoing: [OutgoingChatMessage] = []
    /// The show the listener's unsent messages go under.
    @Published private(set) var outgoingShow: (id: String?, title: String?) = (nil, nil)
    @Published private(set) var pinned: ChatMessage?
    @Published private(set) var hiddenUserIDs: Set<UUID> = []
    @Published private(set) var isLoaded = false
    @Published private(set) var loadFailed = false
    /// The newest message the listener has seen on the home page or in the
    /// chat — what the home page ticker plays from.
    @Published private(set) var lastSeenID: Int64

    static let historyDays = 7
    static let historyLimit = 300
    private static let lastSeenKey = "chat.lastSeenID"

    private var client: SupabaseClient { AppSupabase.client }
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var accountObserver: AnyCancellable?

    private init() {
        lastSeenID = Int64(UserDefaults.standard.integer(forKey: Self.lastSeenKey))
    }

    /// Visible to this listener (hidden listeners left out), oldest first.
    var visibleMessages: [ChatMessage] {
        messages.filter { $0.userID.map { !hiddenUserIDs.contains($0) } ?? true }
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resume() }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause() }
        })
        // Signing in or out changes whose messages are hidden.
        accountObserver = AccountService.shared.$state
            .map(\.isSignedInForChat)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refreshHidden() } }
        resume()
    }

    private func resume() {
        Task {
            await reload()
            await subscribe()
            await refreshHidden()
        }
    }

    private func pause() {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            self.channel = nil
            Task { await channel.unsubscribe() }
        }
    }

    func reload() async {
        let since = Date().addingTimeInterval(-Double(Self.historyDays) * 86_400)
        do {
            let recent: [ChatMessage] = try await client.from("chat_messages")
                .select()
                .gte("created_at", value: ISO8601DateFormatter().string(from: since))
                .order("created_at", ascending: false)
                .limit(Self.historyLimit)
                .execute()
                .value
            let pins: [ChatMessage] = try await client.from("chat_messages")
                .select()
                .filter("pinned_at", operator: "not.is", value: "null")
                .order("pinned_at", ascending: false)
                .limit(1)
                .execute()
                .value
            messages = recent.reversed()
            pinned = pins.first.flatMap { $0.isDeleted ? nil : $0 }
            isLoaded = true
            loadFailed = false
            if lastSeenID == 0, let newest = messages.last {
                // First time: nothing is "new" yet, no ticker to play.
                setLastSeen(newest.id)
            }
        } catch {
            if !isLoaded { loadFailed = true }
        }
    }

    private func subscribe() async {
        guard channel == nil else { return }
        let channel = client.channel("chat-messages")
        self.channel = channel
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "chat_messages")
        do {
            try await channel.subscribeWithError()
        } catch {
            self.channel = nil
            return
        }
        listenTask = Task { [weak self] in
            let decoder = JSONDecoder()
            for await change in changes {
                guard let self else { return }
                switch change {
                case .insert(let action):
                    if let message = try? action.decodeRecord(as: ChatMessage.self, decoder: decoder) {
                        self.upsert(message)
                    }
                case .update(let action):
                    if let message = try? action.decodeRecord(as: ChatMessage.self, decoder: decoder) {
                        self.upsert(message)
                    }
                case .delete(let action):
                    if case .integer(let id)? = action.oldRecord["id"] {
                        self.messages.removeAll { $0.id == Int64(id) }
                    }
                }
            }
        }
    }

    private func upsert(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            let index = messages.firstIndex { $0.createdAt > message.createdAt } ?? messages.endIndex
            messages.insert(message, at: index)
        }
        if message.pinnedAt != nil, !message.isDeleted {
            if pinned == nil || (message.pinnedAt ?? .distantPast) >= (pinned?.pinnedAt ?? .distantPast) {
                pinned = message
            }
        } else if pinned?.id == message.id {
            pinned = nil
        }
    }

    // MARK: - Seen

    func markSeen() {
        if let newest = messages.last, newest.id > lastSeenID { setLastSeen(newest.id) }
    }

    func markSeen(upTo id: Int64) {
        if id > lastSeenID { setLastSeen(id) }
    }

    private func setLastSeen(_ id: Int64) {
        lastSeenID = id
        UserDefaults.standard.set(Int(id), forKey: Self.lastSeenKey)
    }

    // MARK: - Hidden listeners

    func refreshHidden() async {
        guard AccountService.shared.isSignedIn else {
            hiddenUserIDs = []
            return
        }
        if let users = try? await AccountService.shared.hiddenUsers() {
            hiddenUserIDs = Set(users.map(\.userID))
        }
    }

    // MARK: - Sending

    private struct SendParams: Encodable {
        let p_body: String
        let p_show_id: String?
        let p_show_title: String?
    }

    /// Sends `body` under the show on air (the app knows the programme; the
    /// server only checks it). Shows "sending…" right away; on failure the
    /// message stays with "Zkusit znovu", except for errors the listener
    /// must act on (muted, no nickname), which are thrown.
    func send(_ rawBody: String, show: Show?) async throws {
        let body = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let pending = OutgoingChatMessage(id: UUID(), body: String(body.prefix(500)), createdAt: Date(), status: .sending)
        outgoingShow = (show?.id, show?.displayTitle)
        outgoing.append(pending)
        try await deliver(pending.id)
    }

    func retry(_ id: UUID) async throws {
        guard let index = outgoing.firstIndex(where: { $0.id == id }) else { return }
        outgoing[index].status = .sending
        try await deliver(id)
    }

    func discard(_ id: UUID) {
        outgoing.removeAll { $0.id == id }
    }

    private func deliver(_ id: UUID) async throws {
        guard let pending = outgoing.first(where: { $0.id == id }) else { return }
        do {
            let message: ChatMessage = try await client
                .rpc("send_chat_message", params: SendParams(p_body: pending.body, p_show_id: outgoingShow.id, p_show_title: outgoingShow.title))
                .execute()
                .value
            outgoing.removeAll { $0.id == id }
            upsert(message)
            markSeen(upTo: message.id)
        } catch {
            let accountError = AccountError.from(error)
            switch accountError {
            case .muted, .blocked, .nicknameRequired, .notSignedIn, .accountRequired, .messageInvalid:
                outgoing.removeAll { $0.id == id }
                if case .muted = accountError { await AccountService.shared.refresh() }
                if case .blocked = accountError { await AccountService.shared.refresh() }
                throw accountError
            default:
                if let index = outgoing.firstIndex(where: { $0.id == id }) {
                    outgoing[index].status = .failed
                }
                throw accountError
            }
        }
    }
}

#if DEBUG
extension ChatService {
    /// Screenshots and previews.
    func preview(messages: [ChatMessage], pinned: ChatMessage? = nil, lastSeenID: Int64? = nil) {
        self.messages = messages
        self.pinned = pinned
        self.isLoaded = true
        if let lastSeenID { self.lastSeenID = lastSeenID }
    }
}
#endif

private extension AccountService.State {
    var isSignedInForChat: Bool {
        if case .signedIn = self { return true }
        return false
    }
}
