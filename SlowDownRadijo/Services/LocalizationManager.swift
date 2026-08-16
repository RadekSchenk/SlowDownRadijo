import Foundation

/// The two UI languages the app supports. Independent of the system
/// Settings ▸ Language — the user picks this in-app via the header dropdown
/// and it takes effect immediately, no restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    case cs, en

    var id: String { rawValue }
    var displayCode: String { rawValue.uppercased() }

    var displayName: String {
        switch self {
        case .cs: return "Čeština"
        case .en: return "English"
        }
    }
}

/// Holds the currently-selected UI language. Views that show localized
/// text hold an `@ObservedObject` reference to `LocalizationManager.shared`
/// (even if they only call through `L10n` static helpers) so SwiftUI
/// re-renders them the moment the language changes — `@ObservedObject`
/// subscribes to the whole `objectWillChange` stream, not per-property, so
/// this works even though `L10n` reads `.language` indirectly.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "app.language"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .cs
        }
    }
}
