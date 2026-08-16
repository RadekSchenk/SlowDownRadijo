import SwiftUI

/// Light/Dark override the user can set in-app via the header toggle,
/// independent of `AppLanguage` but following the same pattern. `.system`
/// is the default and means "no override" — the app follows whatever
/// Settings ▸ Display & Brightness currently says, until the header
/// toggle's first tap picks an explicit side.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    /// `nil` tells SwiftUI's `.preferredColorScheme` to defer to the
    /// system setting instead of forcing one.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Holds the currently-selected appearance override. Mirrors
/// `LocalizationManager`: a view holding an `@ObservedObject` reference to
/// `AppearanceManager.shared` re-renders the moment the selection changes,
/// no restart needed.
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "app.appearance"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppAppearance(rawValue: raw) {
            appearance = saved
        } else {
            appearance = .system
        }
    }
}
