import XCTest

/// Drives the real app in the simulator: the hand-built tab bar has to
/// switch both the page and the highlight, and a second tap on the current
/// tab has to scroll its page back to the top.
final class TabBarUITests: XCTestCase {
    private let tabs = [0, 3, 5, 4]
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // No sound in CI, and no first-run stream start racing the taps.
        app.launchArguments += ["-autoplayEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 20), "tab bar never appeared\n\(app.debugDescription)")
    }

    func testEveryTabSwitchesPageAndHighlight() {
        assertOnly(selected: 0)
        for tag in [3, 5, 4, 0, 5, 3] {
            app.buttons["tab.\(tag)"].tap()
            assertOnly(selected: tag)
        }
    }

    func testTappingCurrentTabScrollsToTop() {
        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(menu.isHittable, "page did not scroll\n\(app.debugDescription)")
        app.buttons["tab.0"].tap()
        let backAtTop = NSPredicate(format: "isHittable == true")
        expectation(for: backAtTop, evaluatedWith: menu)
        waitForExpectations(timeout: 5)
    }

    private func assertOnly(selected tag: Int, file: StaticString = #filePath, line: UInt = #line) {
        let page = app.descendants(matching: .any)["page.\(tag)"]
        let shown = page.waitForExistence(timeout: 5)
        attachScreenshot(named: "tab \(tag)")
        XCTAssertTrue(shown, "page \(tag) not shown\n\(app.debugDescription)", file: file, line: line)
        for other in tabs {
            let button = app.buttons["tab.\(other)"]
            XCTAssertEqual(button.isSelected, other == tag, "tab \(other) highlight wrong while on \(tag)\n\(app.debugDescription)", file: file, line: line)
            if other != tag {
                XCTAssertFalse(app.descendants(matching: .any)["page.\(other)"].exists, "page \(other) still shown", file: file, line: line)
            }
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
