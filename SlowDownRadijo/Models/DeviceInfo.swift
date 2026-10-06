import UIKit

/// Bundled with every feedback submission (see `FeedbackUploadService`) so
/// a bug report is actually actionable — no user-identifying info, just
/// what's needed to reproduce: app version, OS, hardware, and the app's
/// own language setting at the time of sending.
struct DeviceInfo: Encodable {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let appLanguage: String

    enum CodingKeys: String, CodingKey {
        case appVersion, buildNumber, osVersion, deviceModel, appLanguage
    }

    static func current() -> DeviceInfo {
        let bundle = Bundle.main
        return DeviceInfo(
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            osVersion: "iOS \(UIDevice.current.systemVersion)",
            deviceModel: Self.hardwareIdentifier(),
            appLanguage: LocalizationManager.shared.language.displayCode
        )
    }

    /// Raw hardware identifier (e.g. "iPhone15,3") — `UIDevice.current.model`
    /// only ever returns the generic "iPhone", not enough to tell devices
    /// apart when triaging a bug.
    private static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
