import XCTest

/// The App Store screenshots: the app as a listener sees it, on the live
/// stream, in the language from `SCREENSHOT_LANGUAGE` (cs/en). Run by the
/// appstore-screenshots job in `.github/workflows/ui-tests.yml` (a commit
/// message containing [appstore]) on a 6.9" iPhone with a tidy status bar;
/// skipped by the regular UI tests.
///
/// Best taken while a show with a host is on air, so the home screen shows
/// a show, its host and a confirmed song.
final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var language = "cs"

    func testAppStoreScreenshots() {
        continueAfterFailure = true
        language = ProcessInfo.processInfo.environment["SCREENSHOT_LANGUAGE"] ?? "cs"
        app = XCUIApplication()
        app.launchArguments += [
            "-app.language", language,
            // No consent card on the home screen, and nothing sent from CI.
            "-analytics.consent", "denied",
            // A few weeks of listening, so the stats have something to show.
            "-debugStatsTotalSeconds", "371520",
            // Times as a listener here sees them: the CI Mac runs on UTC
            // and a US region (2:00 PM for the 15:00 end of a show).
            "-AppleLocale", language == "cs" ? "cs_CZ" : "en_GB",
            // A song the station really played (Beat Brunch, 4 Nov 2026):
            // mixtape and talk shows send no song titles, so the live
            // stream may have none to confirm while the screens are taken.
            "-debugVerifiedTrack", "Kokoroko - Never Lost",
        ]
        app.launchEnvironment["TZ"] = "Europe/Prague"
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 60))

        // The radio playing, with a confirmed song under the show.
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " – ")).firstMatch
        _ = song.waitForExistence(timeout: 30)
        sleep(4)
        capture("1 home")

        // The sleep timer sheet with its night sky.
        let timer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                                                     "Nastavit časovač", "Set a sleep timer")).firstMatch
        if timer.exists {
            timer.tap()
            sleep(3)
            capture("2 sleep timer")
            app.swipeDown(velocity: .fast)
            sleep(2)
        }

        // Down the home page until the programme's heading and day picker
        // are near the top.
        scroll(by: 730)
        sleep(2)
        capture("3 programme")

        app.buttons["tab.5"].tap()
        sleep(4)
        capture("4 stats")

        app.buttons["tab.3"].tap()
        sleep(3)
        capture("5 message")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(language) \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A slow drag that stops where it ends instead of flinging the page on.
    private func scroll(by distance: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                    withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.4)
    }
}
