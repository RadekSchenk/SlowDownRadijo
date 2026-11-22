import Foundation
import Supabase

/// The superadmin's "Správa chatu" (Figma Profil M10, A1–A6): moderators from
/// the programme and their invite links, and the admins
/// (backend/supabase/sql/022_chat_v3.sql, `admin_*`).
@MainActor
final class ChatAdmin: ObservableObject {
    static let shared = ChatAdmin()

    struct Host: Decodable, Identifiable, Equatable {
        let hostID: String
        let displayName: String
        let linked: Bool
        let linkedAt: Date?
        let inviteExpiresAt: Date?
        var id: String { hostID }

        enum CodingKeys: String, CodingKey {
            case hostID = "host_id", displayName = "display_name", linked
            case linkedAt = "linked_at", inviteExpiresAt = "invite_expires_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hostID = try c.decode(String.self, forKey: .hostID)
            displayName = try c.decode(String.self, forKey: .displayName)
            linked = (try? c.decode(Bool.self, forKey: .linked)) ?? false
            linkedAt = (try? c.decodeIfPresent(String.self, forKey: .linkedAt)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
            inviteExpiresAt = (try? c.decodeIfPresent(String.self, forKey: .inviteExpiresAt)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
        }
    }

    struct Admin: Decodable, Identifiable, Equatable {
        let userID: UUID
        let nickname: String?
        let isSuperadmin: Bool
        let adminSince: Date?
        let isMe: Bool
        var id: UUID { userID }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id", nickname, isSuperadmin = "is_superadmin", adminSince = "admin_since", isMe = "is_me"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            userID = try c.decode(UUID.self, forKey: .userID)
            nickname = try? c.decodeIfPresent(String.self, forKey: .nickname)
            isSuperadmin = (try? c.decode(Bool.self, forKey: .isSuperadmin)) ?? false
            adminSince = (try? c.decodeIfPresent(String.self, forKey: .adminSince)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
            isMe = (try? c.decode(Bool.self, forKey: .isMe)) ?? false
        }
    }

    struct Overview: Decodable, Equatable {
        let hosts: [Host]
        let admins: [Admin]
    }

    struct Invite: Decodable, Hashable {
        let code: String
        let expiresAt: Date?
        let hostID: String

        var url: URL { URL(string: "https://slowdownradijo.cz/dj/\(code)")! }

        enum CodingKeys: String, CodingKey { case code, expiresAt = "expires_at", hostID = "host_id" }

        init(code: String, expiresAt: Date?, hostID: String) {
            self.code = code
            self.expiresAt = expiresAt
            self.hostID = hostID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decode(String.self, forKey: .code)
            hostID = try c.decode(String.self, forKey: .hostID)
            expiresAt = (try? c.decodeIfPresent(String.self, forKey: .expiresAt)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
        }
    }

    struct FoundUser: Decodable, Identifiable, Equatable {
        let userID: UUID
        let nickname: String?
        let registeredAt: Date?
        let isAdmin: Bool
        var id: UUID { userID }

        enum CodingKeys: String, CodingKey { case userID = "user_id", nickname, registeredAt = "registered_at", isAdmin = "is_admin" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            userID = try c.decode(UUID.self, forKey: .userID)
            nickname = try? c.decodeIfPresent(String.self, forKey: .nickname)
            registeredAt = (try? c.decodeIfPresent(String.self, forKey: .registeredAt)).flatMap { $0 }.flatMap(ChatMessage.parseDate)
            isAdmin = (try? c.decode(Bool.self, forKey: .isAdmin)) ?? false
        }
    }

    /// A moderator as the programme knows them: one name, maybe several shows.
    struct ProgrammeHost: Identifiable, Hashable {
        let id: String
        let name: String
        let shows: [String]
    }

    @Published private(set) var overview: Overview?

    private var client: SupabaseClient { AppSupabase.client }

    private init() {}

    func reload() async throws {
        overview = try await call { try await self.client.rpc("admin_overview").execute().value }
    }

    func createInvite(hostID: String, name: String) async throws -> Invite {
        struct Params: Encodable { let p_host_id: String; let p_display_name: String }
        let invite: Invite = try await call {
            try await self.client.rpc("admin_create_host_invite", params: Params(p_host_id: hostID, p_display_name: name)).execute().value
        }
        try? await reload()
        return invite
    }

    func unlink(hostID: String) async throws {
        try await call { try await self.client.rpc("admin_unlink_host", params: ["p_host_id": hostID]).execute() }
        try? await reload()
    }

    func findUsers(_ query: String) async throws -> [FoundUser] {
        try await call { try await self.client.rpc("admin_find_users", params: ["p_query": query]).execute().value }
    }

    func setAdmin(_ userID: UUID, on: Bool) async throws {
        struct Params: Encodable { let p_user: UUID; let p_on: Bool }
        try await call { try await self.client.rpc("admin_set_admin", params: Params(p_user: userID, p_on: on)).execute() }
        try? await reload()
    }

    private func call<T>(_ work: @escaping () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            throw AccountError.from(error)
        }
    }

    /// The moderators in the programme, each once with all their shows.
    static func programmeHosts(_ schedule: ScheduleStore) -> [ProgrammeHost] {
        var shows: [String: [String]] = [:]
        var names: [String: String] = [:]
        for show in schedule.days.flatMap(\.shows) + ScheduleStore.catalog {
            guard let name = show.hostName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            let id = hostID(for: name)
            names[id] = names[id] ?? name
            if !(shows[id] ?? []).contains(show.displayTitle) { shows[id, default: []].append(show.displayTitle) }
        }
        return names.map { ProgrammeHost(id: $0.key, name: $0.value, shows: shows[$0.key] ?? []) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// "DJ Pufaz" → "dj-pufaz", as `chat_hosts.host_id`.
    static func hostID(for name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "cs_CZ")).lowercased()
        let dashed = folded.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? String($0) : "-" }.joined()
        let collapsed = dashed.split(separator: "-").joined(separator: "-")
        return String(collapsed.prefix(80))
    }
}
