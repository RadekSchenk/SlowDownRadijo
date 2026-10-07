import Foundation
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

    static func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, account: String) {
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
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
