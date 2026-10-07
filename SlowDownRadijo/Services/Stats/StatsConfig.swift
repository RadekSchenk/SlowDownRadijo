import Foundation

/// Where the listening stats live. Same Supabase project and public
/// ("publishable") key as `RemoteHistoryService` — safe to embed: everything
/// it can reach is guarded by row level security and security-definer
/// functions (see `backend/supabase/sql/005_listener_stats.sql`).
enum StatsConfig {
    static let baseURL = URL(string: "https://toqoqrshyutyezoyxvlj.supabase.co")!
    static let publishableKey = "sb_publishable_KjKHzi03xlmnhNAnxD87oQ_6p-Qb1Su"

    /// `UserDefaults` key behind Settings ▸ "Statistiky poslechu". On unless
    /// the listener turns it off — nothing is measured or sent while it's off.
    static let enabledKey = "statsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// The switch is mirrored into the Keychain, which — like the anonymous
    /// session — survives deleting and reinstalling the app. Otherwise a
    /// reinstall would quietly switch measuring back on under the same id.
    private static let keychainAccount = "stats.enabled"

    static func rememberPreference() {
        KeychainStore.write(Data((isEnabled ? "1" : "0").utf8), account: keychainAccount)
    }

    /// After a reinstall `UserDefaults` is empty; take the choice from the
    /// Keychain before anything is measured.
    static func restorePreferenceIfNeeded() {
        guard UserDefaults.standard.object(forKey: enabledKey) == nil,
              let stored = KeychainStore.read(account: keychainAccount) else { return }
        UserDefaults.standard.set(stored == Data("1".utf8), forKey: enabledKey)
    }
}
