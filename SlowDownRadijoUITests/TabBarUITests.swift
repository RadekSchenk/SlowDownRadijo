import XCTest

/// Drives the real app in the simulator: the hand-built tab bar has to
/// switch both the page and the highlight, sit where the design puts it,
/// and a second tap on the current tab has to scroll its page to the top.
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

    /// The tabs' labels end 29pt above the screen's bottom edge (19pt
    /// home-indicator strip + 10pt padding, Figma `bottom-nav`).
    func testTabBarSitsAtTheDesignedHeight() {
        let screenHeight = app.windows.firstMatch.frame.height
        for tag in tabs {
            let bottom = app.buttons["tab.\(tag)"].frame.maxY
            XCTAssertEqual(bottom, screenHeight - 29, accuracy: 1, "tab \(tag) ends at \(bottom), screen \(screenHeight)")
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

    func testStatsBlockOpensStatsTab() {
        let statsBlock = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Your listening stats", "Tvoje statistiky")).firstMatch
        XCTAssertTrue(statsBlock.waitForExistence(timeout: 10))
        statsBlock.tap()
        assertOnly(selected: 5)
    }

    private func assertOnly(selected tag: Int, file: StaticString = #filePath, line: UInt = #line) {
        let shown = app.descendants(matching: .any)["page.\(tag)"].waitForExistence(timeout: 5)
        attachScreenshot(named: "tab \(tag)")
        XCTAssertTrue(shown, "page \(tag) not shown\n\(app.debugDescription)", file: file, line: line)
        for other in tabs {
            XCTAssertEqual(app.buttons["tab.\(other)"].isSelected, other == tag, "tab \(other) highlight wrong while on \(tag)", file: file, line: line)
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
