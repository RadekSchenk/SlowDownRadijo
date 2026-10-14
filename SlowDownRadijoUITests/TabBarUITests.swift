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

    func testDiagnostics() {
        sleep(5)
        let probe = app.descendants(matching: .any)["debug.hit"]
        print("[uitest] probe: \(probe.label)")
        let tab3 = app.buttons["tab.3"]
        tab3.tap()
        sleep(1)
        print("[uitest] after element tap: \(String(describing: tab3.value)) probe value=\(String(describing: probe.value))")
        let center = tab3.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()
        sleep(1)
        print("[uitest] after coordinate tap: \(String(describing: tab3.value)) probe value=\(String(describing: probe.value))")
        let statsBlock = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Your listening stats")).firstMatch
        print("[uitest] stats block exists=\(statsBlock.exists) hittable=\(statsBlock.exists && statsBlock.isHittable)")
        if statsBlock.exists {
            statsBlock.tap()
            sleep(2)
            print("[uitest] after stats block tap: page5=\(app.descendants(matching: .any)["page.5"].exists) page0=\(app.descendants(matching: .any)["page.0"].exists) tab5=\(String(describing: app.buttons["tab.5"].value))")
        }
        let play = app.buttons["play.fill"]
        print("[uitest] play exists=\(play.exists)")
        if play.exists {
            play.tap()
            sleep(2)
            print("[uitest] after play tap: play.fill exists=\(app.buttons["play.fill"].exists)")
        }
        print("[uitest] probe again: \(probe.label)")
        attachScreenshot(named: "diagnostics")
    }

    func testEveryTabSwitchesPageAndHighlight() {
        assertOnly(selected: 0)
        for tag in [3, 5, 4, 0, 5, 3] {
            let button = app.buttons["tab.\(tag)"]
            print("[uitest] before tap \(tag): frame=\(button.frame) hittable=\(button.isHittable) value=\(String(describing: button.value))")
            button.tap()
            sleep(1)
            print("[uitest] after tap \(tag): value=\(String(describing: button.value)) selected=\(button.isSelected)")
            print("[uitest] hierarchy after tap \(tag):\n\(app.debugDescription)")
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
