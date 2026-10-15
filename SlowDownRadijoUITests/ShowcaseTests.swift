import XCTest

/// Walks through the app for the showcase video made by
/// `.github/workflows/showcase.yml`, which records the simulator while this
/// runs, then adds captions and the live stream's sound.
///
/// XCUITest waits for the app to settle before every gesture, and with the
/// radio playing something always moves, so most of the run is waiting.
/// Each action therefore prints a `SHOWCASE_CLIP <scene> <from> <to>` line
/// (unix times: from just before the gesture to the end of the pause after
/// it), and only those stretches make it into the video. Skipped by the
/// regular UI tests; nothing here fails the run if a step can't be done.
final class ShowcaseTests: XCTestCase {
    private var app: XCUIApplication!
    /// The caption the next clips go under.
    private var scene = "home"

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
        app.launch()
        _ = app.buttons["tab.0"].waitForExistence(timeout: 60)
        // The launch cover fading into the app, the stream starting.
        let shown = now()
        pause(5)
        clip(from: shown - 1.5, to: now())

        browseSongs()
        pullDown()
        sleepTimer()
        scrollHome()
        tab(5, scene: "stats", scrollBy: 260)
        tab(3, scene: "message", scrollBy: 0)
        tab(4, scene: "support", scrollBy: 200)
        menu()
    }

    // MARK: - Scenes

    /// Swipes the song line back through the earlier songs and returns. The
    /// first song can take a while to be confirmed; the wait isn't filmed.
    private func browseSongs() {
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " – ")).firstMatch
        guard song.waitForExistence(timeout: 120) else { return }
        scene = "songs"
        act(hold: 2) {}
        for _ in 0..<2 {
            act(lead: 0.8, hold: 2.2) {
                drag(from: song.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)), dx: 240, dy: 0)
            }
        }
        for _ in 0..<2 {
            act(lead: 0.8, hold: 1.2) {
                drag(from: song.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)), dx: -240, dy: 0)
            }
        }
    }

    /// The header grows as the page is pulled past its top.
    private func pullDown() {
        act(lead: 1.9, hold: 1.2) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 200)),
                        withVelocity: XCUIGestureVelocity(220), thenHoldForDuration: 0.8)
        }
    }

    private func sleepTimer() {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nastavit časovač")).firstMatch
        guard button.exists else { return }
        scene = "timer"
        act(hold: 2) { button.tap() }
        let thirty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "30")).firstMatch
        // The countdown ticks in the player row.
        act(hold: 3.5) {
            if thirty.waitForExistence(timeout: 3) {
                thirty.tap()
            } else {
                app.swipeDown()
            }
        }
    }

    /// Down the home page: the header fades away, the stats and the
    /// programme rise into view.
    private func scrollHome() {
        scene = "scroll"
        for _ in 0..<2 {
            act(lead: 0.8, hold: 1.4) { scroll(by: 230) }
        }
        scene = "program"
        for _ in 0..<4 {
            act(lead: 0.8, hold: 1.3) { scroll(by: 260) }
        }
    }

    private func tab(_ tag: Int, scene name: String, scrollBy distance: CGFloat) {
        scene = name
        act(hold: 2.5) { app.buttons["tab.\(tag)"].tap() }
        if distance > 0 {
            act(lead: 0.8, hold: 2) { scroll(by: distance) }
        }
    }

    /// Back home, to the top, then the menu and the language switch.
    private func menu() {
        scene = "menu"
        act(hold: 0.8) { app.buttons["tab.0"].tap() }
        // Tapping the current tab again scrolls its page to the top.
        act(hold: 1.5) { app.buttons["tab.0"].tap() }
        act(hold: 2) { app.buttons["Menu"].firstMatch.tap() }
        let english = app.buttons["language.en"]
        if english.waitForExistence(timeout: 3) {
            act(hold: 2) { english.tap() }
            act(hold: 1.5) { app.buttons["language.cs"].tap() }
        }
        act(lead: 0.6, hold: 2) { app.swipeDown(velocity: .slow) }
    }

    // MARK: - Helpers

    /// Runs a gesture, holds for `hold` seconds, and marks the stretch to
    /// film: from `lead` seconds before the gesture finished (about how long
    /// it takes) to the end of the hold.
    private func act(lead: Double = 0.4, hold: Double, _ action: () -> Void) {
        action()
        let done = now()
        pause(hold)
        clip(from: done - lead, to: now())
    }

    private func clip(from start: Double, to end: Double) {
        print("SHOWCASE_CLIP \(scene) \(start) \(end)")
    }

    private func now() -> Double { Date().timeIntervalSince1970 }

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
