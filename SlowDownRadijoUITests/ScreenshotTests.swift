import XCTest

/// Screens of the app at a given text size and language, as attachments —
/// for checking layouts with large text and for App Store screenshots.
/// Run by `.github/workflows/screenshots.yml`; skipped by the regular UI
/// tests. Settings come from the environment: `SCREENSHOT_TEXT_SIZE`
/// (a `UIContentSizeCategory` raw value) and `SCREENSHOT_LANGUAGE` (cs/en).
final class ScreenshotTests: XCTestCase {
    func testCaptureScreens() {
        let environment = ProcessInfo.processInfo.environment
        let textSize = environment["SCREENSHOT_TEXT_SIZE"] ?? "UICTContentSizeCategoryL"
        let language = environment["SCREENSHOT_LANGUAGE"] ?? "cs"

        let app = XCUIApplication()
        app.launchArguments += [
            "-autoplayEnabled", "NO",
            "-app.language", language,
            "-UIPreferredContentSizeCategoryName", textSize,
        ]
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 60))
        sleep(4)

        let prefix = "\(language) \(textSize.replacingOccurrences(of: "UICTContentSizeCategory", with: ""))"
        capture(app, "\(prefix) 1 home")
        app.swipeUp()
        sleep(1)
        capture(app, "\(prefix) 2 home scrolled")
        for (tag, name) in [(5, "3 stats"), (3, "4 message"), (4, "5 support")] {
            app.buttons["tab.\(tag)"].tap()
            sleep(2)
            capture(app, "\(prefix) \(name)")
        }
        app.buttons["tab.0"].tap()
        sleep(1)
        app.buttons["Menu"].firstMatch.tap()
        sleep(2)
        capture(app, "\(prefix) 6 menu")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
