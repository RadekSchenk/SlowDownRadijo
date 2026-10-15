import XCTest

/// Walks through the app slowly enough to film it, for the showcase video
/// made by `.github/workflows/showcase.yml` (which records the simulator
/// while this runs, then adds captions and the live stream's sound). Each
/// scene prints a `SHOWCASE_MARK <scene> <unix time>` line; the captions
/// are timed from those. Skipped by the regular UI tests.
///
/// Nothing here fails the run if a step can't be done (no song verified
/// yet, say): the video just goes without that scene.
final class ShowcaseTests: XCTestCase {
    private var app: XCUIApplication!

    func testShowcase() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += [
            "-app.language", "cs",
            // No analytics from a CI run.
            "-analytics.consent", "denied",
            // A few days of listening, so the stats have something to show.
            "-debugStatsTotalSeconds", "371520",
        ]
        mark("launch")
        app.launch()
        _ = app.buttons["tab.0"].waitForExistence(timeout: 60)
        mark("home")
        // The stream connects, the equalizer starts, the song appears.
        pause(6)

        browseSongs()
        pullDown()
        sleepTimer()
        scrollHome()
        tab(5, scene: "stats", scrollBy: 260)
        tab(3, scene: "message", scrollBy: 0)
        tab(4, scene: "support", scrollBy: 200)
        menu()
        mark("end")
        pause(1)
    }

    // MARK: - Scenes

    /// Swipes the song line back through the earlier songs and returns.
    private func browseSongs() {
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " – ")).firstMatch
        guard song.waitForExistence(timeout: 25) else { return }
        pause(1)
        mark("songs")
        for _ in 0..<2 {
            drag(from: song.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)), dx: 240, dy: 0)
            pause(2.2)
        }
        for _ in 0..<2 {
            drag(from: song.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)), dx: -240, dy: 0)
            pause(1.2)
        }
    }

    /// The header grows as the page is pulled past its top.
    private func pullDown() {
        mark("pull")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 200)),
                    withVelocity: XCUIGestureVelocity(220), thenHoldForDuration: 0.8)
        pause(1.5)
    }

    private func sleepTimer() {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nastavit časovač")).firstMatch
        guard button.exists else { return }
        mark("timer")
        button.tap()
        pause(2)
        let thirty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "30")).firstMatch
        if thirty.waitForExistence(timeout: 3) {
            thirty.tap()
        } else {
            app.swipeDown()
        }
        // The countdown ticks in the player row.
        pause(3.5)
    }

    /// Down the home page: the header fades away, the stats and the
    /// programme rise into view.
    private func scrollHome() {
        mark("scroll")
        for _ in 0..<3 {
            scroll(by: 230)
            pause(1.3)
        }
        mark("program")
        for _ in 0..<3 {
            scroll(by: 280)
            pause(1.3)
        }
        pause(0.8)
    }

    private func tab(_ tag: Int, scene: String, scrollBy distance: CGFloat) {
        mark(scene)
        app.buttons["tab.\(tag)"].tap()
        pause(2.5)
        if distance > 0 {
            scroll(by: distance)
            pause(2)
        }
    }

    /// Back home, to the top, then the menu and the language switch.
    private func menu() {
        mark("menu")
        app.buttons["tab.0"].tap()
        pause(0.8)
        // Tapping the current tab again scrolls its page to the top.
        app.buttons["tab.0"].tap()
        pause(1.5)
        app.buttons["Menu"].firstMatch.tap()
        pause(2)
        let english = app.buttons["language.en"]
        if english.waitForExistence(timeout: 3) {
            english.tap()
            pause(2)
            app.buttons["language.cs"].tap()
            pause(1.5)
        }
        app.swipeDown(velocity: .slow)
        pause(2)
    }

    // MARK: - Helpers

    private func mark(_ scene: String) {
        print("SHOWCASE_MARK \(scene) \(Date().timeIntervalSince1970)")
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// A slow, deliberate drag that stops where it ends instead of flinging
    /// the page on.
    private func drag(from start: XCUICoordinate, dx: CGFloat, dy: CGFloat) {
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                    withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.15)
    }

    private func scroll(by distance: CGFloat) {
        drag(from: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)), dx: 0, dy: -distance)
    }
}
