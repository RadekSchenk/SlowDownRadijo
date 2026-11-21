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
    @Published fileprivate(set) var messages: [ChatMessage] = []
    @Published private(set) var outgoing: [OutgoingChatMessage] = []
    /// The show the listener's unsent messages go under.
    @Published private(set) var outgoingShow: (id: String?, title: String?) = (nil, nil)
    @Published fileprivate(set) var pinned: ChatMessage?
    @Published fileprivate(set) var hiddenUserIDs: Set<UUID> = []
    @Published private(set) var isLoaded = false
    @Published private(set) var loadFailed = false
    /// The newest message the listener has seen on the home page or in the
    /// chat — what the home page ticker plays from.
    @Published private(set) var lastSeenID: Int64
    /// Set to open the chat sheet from outside the home page.
    @Published fileprivate(set) var openRequestID: UUID?
    /// A DJ invite link the app was opened with (`handleInvite`).
    @Published var pendingInvite: PendingInvite?

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
        #if DEBUG
        // Store screenshots: the sample chat stays, nothing from the server.
        if StoreDemo.isOn { return }
        #endif
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
            case .muted, .blocked, .nicknameRequired, .notSignedIn, .accountRequired, .messageInvalid,
                 .duplicateMessage, .linksNeedAccount:
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

// MARK: - Moderation and reports (phase 5)

extension ChatService {
    /// What a moderator sees about an author in the message menu
    /// ("Ztlumený do zítra 8:04 · ztlumil DJ Pufaz").
    struct UserStatus: Decodable, Equatable {
        let mutedUntil: Date?
        let blocked: Bool
        let mutedBy: String?

        var isMuted: Bool { blocked || (mutedUntil.map { $0 > Date() } ?? false) }

        enum CodingKeys: String, CodingKey {
            case mutedUntil = "muted_until", blocked, mutedBy = "muted_by"
        }

        init(mutedUntil: Date?, blocked: Bool, mutedBy: String?) {
            self.mutedUntil = mutedUntil
            self.blocked = blocked
            self.mutedBy = mutedBy
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mutedUntil = (try? c.decodeIfPresent(String.self, forKey: .mutedUntil)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
            blocked = (try? c.decode(Bool.self, forKey: .blocked)) ?? false
            mutedBy = try? c.decodeIfPresent(String.self, forKey: .mutedBy)
        }
    }

    /// A DJ invite before it is claimed (`host_invite_info`, 021).
    struct InviteInfo: Decodable, Equatable {
        let hostName: String
        let expiresAt: Date?

        enum CodingKeys: String, CodingKey { case hostName = "host_name", expiresAt = "expires_at" }

        init(hostName: String, expiresAt: Date?) {
            self.hostName = hostName
            self.expiresAt = expiresAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hostName = try c.decode(String.self, forKey: .hostName)
            expiresAt = (try? c.decodeIfPresent(String.self, forKey: .expiresAt)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
        }
    }

    private struct MessageParam: Encodable { let p_message_id: Int64 }
    private struct UserParam: Encodable { let p_user: UUID }
    private struct MuteParams: Encodable { let p_user: UUID; let p_minutes: Int; let p_message_id: Int64? }
    private struct BlockParams: Encodable { let p_user: UUID; let p_message_id: Int64? }
    private struct CodeParam: Encodable { let p_code: String }

    private func call(_ function: String, _ params: some Encodable) async throws {
        do {
            try await AppSupabase.client.rpc(function, params: params).execute()
        } catch {
            throw AccountError.from(error)
        }
    }

    func report(_ message: ChatMessage) async throws {
        try await call("report_chat_message", MessageParam(p_message_id: message.id))
    }

    func hide(_ userID: UUID) async throws {
        try await call("hide_chat_user", UserParam(p_user: userID))
        hiddenUserIDs.insert(userID)
    }

    func unhide(_ userID: UUID) async throws {
        try await call("unhide_chat_user", UserParam(p_user: userID))
        hiddenUserIDs.remove(userID)
    }

    func delete(_ message: ChatMessage) async throws {
        try await call("delete_chat_message", MessageParam(p_message_id: message.id))
        replace(message.id) { old in
            ChatMessage(id: old.id, userID: old.userID, authorName: old.authorName, role: old.role, body: nil,
                        showID: old.showID, showTitle: old.showTitle, createdAt: old.createdAt, deletedAt: Date(), pinnedAt: nil)
        }
        if pinned?.id == message.id { pinned = nil }
    }

    /// "Vrátit" within 10 minutes of deleting.
    func restore(_ message: ChatMessage) async throws {
        try await call("restore_chat_message", MessageParam(p_message_id: message.id))
        replace(message.id) { _ in message }
        if message.pinnedAt != nil, pinned == nil { pinned = message }
    }

    func pin(_ message: ChatMessage) async throws {
        try await call("pin_chat_message", MessageParam(p_message_id: message.id))
        let now = Date()
        if let old = pinned, old.id != message.id {
            replace(old.id) { m in
                ChatMessage(id: m.id, userID: m.userID, authorName: m.authorName, role: m.role, body: m.body,
                            showID: m.showID, showTitle: m.showTitle, createdAt: m.createdAt, deletedAt: m.deletedAt, pinnedAt: nil)
            }
        }
        let updated = ChatMessage(id: message.id, userID: message.userID, authorName: message.authorName, role: message.role, body: message.body,
                                  showID: message.showID, showTitle: message.showTitle, createdAt: message.createdAt, deletedAt: nil, pinnedAt: now)
        replace(message.id) { _ in updated }
        pinned = updated
    }

    func unpin() async throws {
        try await call("unpin_chat_message", [String: String]())
        if let old = pinned {
            replace(old.id) { m in
                ChatMessage(id: m.id, userID: m.userID, authorName: m.authorName, role: m.role, body: m.body,
                            showID: m.showID, showTitle: m.showTitle, createdAt: m.createdAt, deletedAt: m.deletedAt, pinnedAt: nil)
            }
        }
        pinned = nil
    }

    /// Mutes for 60, 1440 or 10080 minutes; returns when it ends.
    @discardableResult
    func mute(_ userID: UUID, minutes: Int, message: ChatMessage?) async throws -> Date? {
        do {
            let text: String = try await AppSupabase.client
                .rpc("mute_chat_user", params: MuteParams(p_user: userID, p_minutes: minutes, p_message_id: message?.id))
                .execute().value
            return ChatMessage.parseDate(text)
        } catch {
            throw AccountError.from(error)
        }
    }

    func unmute(_ userID: UUID) async throws {
        try await call("unmute_chat_user", UserParam(p_user: userID))
    }

    func block(_ userID: UUID, message: ChatMessage?) async throws {
        try await call("block_chat_user", BlockParams(p_user: userID, p_message_id: message?.id))
    }

    func status(of userID: UUID) async throws -> UserStatus {
        do {
            return try await AppSupabase.client.rpc("chat_user_status", params: UserParam(p_user: userID)).execute().value
        } catch {
            throw AccountError.from(error)
        }
    }

    /// `nil` for an unknown, used or expired code.
    func inviteInfo(_ code: String) async throws -> InviteInfo? {
        do {
            let info: InviteInfo? = try await AppSupabase.client.rpc("host_invite_info", params: CodeParam(p_code: code)).execute().value
            return info
        } catch {
            throw AccountError.from(error)
        }
    }

    private func replace(_ id: Int64, with change: (ChatMessage) -> ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = change(messages[index])
    }

    // MARK: Opening from elsewhere

    /// Opens the chat sheet on the home page (from the DJ invite).
    func requestOpen() {
        openRequestID = UUID()
    }

    /// `https://slowdownradijo.cz/dj/<code>` or `slowdownradijo://dj/<code>`.
    static func inviteCode(from url: URL) -> String? {
        let parts: [String]
        if url.scheme == "slowdownradijo", url.host == "dj" {
            parts = url.pathComponents.filter { $0 != "/" }
        } else if ["https", "http"].contains(url.scheme ?? ""),
                  let host = url.host, host == "slowdownradijo.cz" || host == "www.slowdownradijo.cz" {
            let path = url.pathComponents.filter { $0 != "/" }
            guard path.first == "dj" else { return nil }
            parts = Array(path.dropFirst())
        } else {
            return nil
        }
        guard let code = parts.first?.lowercased(), code.wholeMatch(of: /[0-9a-f]{6,64}/) != nil else { return nil }
        return code
    }

    /// Handles a DJ invite link; `false` for any other URL.
    func handleInvite(_ url: URL) -> Bool {
        guard let code = Self.inviteCode(from: url) else { return false }
        pendingInvite = PendingInvite(code: code)
        return true
    }
}

struct PendingInvite: Identifiable, Equatable {
    let code: String
    var id: String { code }
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
