import Foundation
import OSLog
import Security

/// Minimal generic-password Keychain wrapper for the anonymous listener
/// session. Unlike `UserDefaults`, a Keychain item normally survives
/// deleting and reinstalling the app, so a reinstall continues as the same
/// anonymous listener instead of inflating the listener count and splitting
/// someone's history in two.
///
/// `AfterFirstUnlockThisDeviceOnly`: readable while the phone is locked
/// (background playback keeps uploading), never synced to iCloud or restored
/// onto another device — moving between devices is what registration will be
/// for.
enum KeychainStore {
    private static let service = "cz.slowdownradijo.app.stats"
    private static let logger = Logger(subsystem: "cz.slowdownradijo.app", category: "Keychain")

    static func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error("Keychain read \(account, privacy: .public) failed: \(status)")
            }
            return nil
        }
        return result as? Data
    }

    /// `false` when the value couldn't be saved. An existing item that can't
    /// be updated (wrong attributes, damaged) is replaced rather than left
    /// holding an old value.
    @discardableResult
    static func write(_ data: Data, account: String) -> Bool {
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess { return true }
        if updated != errSecItemNotFound {
            logger.error("Keychain update \(account, privacy: .public) failed: \(updated), replacing")
            SecItemDelete(query as CFDictionary)
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(add as CFDictionary, nil)
        if added != errSecSuccess {
            logger.error("Keychain add \(account, privacy: .public) failed: \(added)")
        }
        return added == errSecSuccess
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
