import XCTest

/// The App Store screenshots: the app as a listener sees it, on the live
/// stream, in the language from `SCREENSHOT_LANGUAGE` (cs/en). Run by the
/// appstore-screenshots job in `.github/workflows/ui-tests.yml` (a commit
/// message containing [appstore]) on a 6.9" iPhone with a tidy status bar;
/// skipped by the regular UI tests.
///
/// With `-storeDemo YES` the app's clock stands at Monday 16 Nov 2026, 7:40
/// (Morning Coffee with DJ Pufaz on air) and the chat, the signed-in
/// Slowrider and the stats are samples (`StoreDemo`), so the screens can be
/// taken at any time.
final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var language = "cs"

    func testAppStoreScreenshots() {
        continueAfterFailure = true
        language = ProcessInfo.processInfo.environment["SCREENSHOT_LANGUAGE"] ?? "cs"
        app = XCUIApplication()
        app.launchArguments += [
            "-app.language", language,
            // Nothing from CI in the station's listening stats.
            "-statsDryRun", "YES",
            // No consent card on the home screen, and nothing sent from CI.
            "-analytics.consent", "denied",
            // Morning Coffee on air, the sample chat, Slowrider and stats.
            "-storeDemo", "YES",
            // The sample contest: its card on the home page and its page.
            "-contestDemo", "YES",
            // Times as a listener here sees them: the CI Mac runs on UTC
            // and a US region (2:00 PM for the 15:00 end of a show).
            "-AppleLocale", language == "cs" ? "cs_CZ" : "en_GB",
            // A song the station really played (Beat Brunch, 4 Nov 2026):
            // mixtape and talk shows send no song titles, so the live
            // stream may have none to confirm while the screens are taken.
            "-debugVerifiedTrack", "Khruangbin - Maria También",
            // Vzkaz with a recorded message ready to send, rather than the
            // empty screen (the CI simulator has no microphone).
            "-debugRecordedVoiceMessage", "YES",
        ]
        app.launchEnvironment["TZ"] = "Europe/Prague"
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 60))

        // The radio playing, with a confirmed song under the show.
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " – ")).firstMatch
        _ = song.waitForExistence(timeout: 30)
        // Wait until the stream really plays (the pause button), not
        // "Připojování…".
        let pause = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Pozastavit rádio", "Pause radio")).firstMatch
        _ = pause.waitForExistence(timeout: 60)
        sleep(4)
        capture("1 home")

        // The contest page (1.3), from its card under the player, with an answer picked.
        let contest = app.buttons["contest.infobox"]
        if contest.waitForExistence(timeout: 5) {
            contest.tap()
            sleep(2)
            let option = app.buttons["contest.option.B"]
            if option.waitForExistence(timeout: 5), option.isHittable {
                option.tap()
                sleep(1)
            }
            capture("7 contest")
            let close = app.buttons["contest.sheet.close"]
            if close.exists { close.tap() } else { app.swipeDown(velocity: .fast) }
            sleep(2)
        }

        // The chat, opened from its section on the home page.
        let chat = app.buttons["chat.open"]
        for _ in 0..<4 where !(chat.exists && chat.isHittable) {
            scroll(by: 300)
            sleep(1)
        }
        if chat.exists {
            chat.tap()
            sleep(3)
            capture("2 chat")
            app.swipeDown(velocity: .fast)
            sleep(2)
        }

        app.buttons["tab.6"].tap()
        sleep(3)
        capture("3 profile")

        app.buttons["tab.5"].tap()
        sleep(4)
        capture("4 stats")

        // The programme: down the home page until its heading sits just
        // under the status bar. A drag doesn't move the page by exactly its
        // length, so measure and correct once.
        app.buttons["tab.0"].tap()
        sleep(2)
        // Saturday: the weekdays have Show podle Majkla, which stays out of
        // the store (`SCREENSHOT_PROGRAMME_DAY` picks another day; Calendar
        // weekday, 1 = Sunday).
        let day = ProcessInfo.processInfo.environment["SCREENSHOT_PROGRAMME_DAY"].flatMap { $0.isEmpty ? nil : $0 } ?? "7"
        let chip = app.buttons["day.\(day)"]
        if chip.waitForExistence(timeout: 5) { chip.tap() }
        sleep(1)
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@ OR label == %@", "Pořady", "Shows")).firstMatch
        for _ in 0..<4 where heading.exists {
            let offset = heading.frame.minY - 80
            if abs(offset) < 12 { break }
            scroll(by: offset)
            sleep(1)
        }
        sleep(2)
        capture("5 programme")

        app.buttons["tab.3"].tap()
        sleep(3)
        capture("6 message")
    }

    /// Shows that must not appear in the App Store screenshots (the
    /// station's call): capturing while one is on air, or listed in the
    /// programme, fails the test, so those screens aren't used.
    private static let excludedShows = ["Majkl"]

    private func capture(_ name: String) {
        // Only what is on the screen counts: a show further down the
        // programme, out of the picture, is fine.
        let screen = app.windows.firstMatch.frame
        for show in Self.excludedShows {
            let matches = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", show)).allElementsBoundByIndex
            for element in matches where element.exists && screen.intersects(element.frame) {
                XCTFail("\(name): \(show) is on screen — retake at another time")
            }
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(language) \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A slow drag that stops where it ends instead of flinging the page
    /// on; a negative distance scrolls back up.
    private func scroll(by distance: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: distance > 0 ? 0.8 : 0.25))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                    withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.6)
    }
}
