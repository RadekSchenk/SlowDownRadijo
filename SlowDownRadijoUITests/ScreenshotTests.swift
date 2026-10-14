import XCTest

/// Screens of the app at a given text size and language, as attachments —
/// for checking layouts with large text and for App Store screenshots.
/// Run by the screenshots job in `.github/workflows/ui-tests.yml`; skipped by the regular UI
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
        reportOverflow(app, name)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Lists elements that stick out past the screen's sides (large text
    /// pushing a layout wider than the screen).
    private func reportOverflow(_ app: XCUIApplication, _ name: String) {
        let width = app.windows.firstMatch.frame.width
        let snapshot = try? app.snapshot()
        var found: [String] = []
        func walk(_ element: XCUIElementSnapshot, depth: Int) {
            let frame = element.frame
            if frame.width > 0, frame.minX < -1 || frame.maxX > width + 1 {
                found.append("\(String(repeating: " ", count: depth))\(element.elementType.rawValue) x=\(Int(frame.minX)) w=\(Int(frame.width)) id=\(element.identifier) label=\(element.label.prefix(40))")
            }
            for child in element.children { walk(child, depth: depth + 1) }
        }
        if let snapshot { walk(snapshot, depth: 0) }
        print("[overflow] \(name): \(found.count) elements")
        for line in found.prefix(40) { print("[overflow]   \(line)") }
    }
}
