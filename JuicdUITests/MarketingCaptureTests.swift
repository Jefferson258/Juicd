import XCTest

final class MarketingCaptureTests: XCTestCase {
    func testCaptureTourneyBracketForWebsite() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-dev-signin"]
        app.launch()

        let out = "/Users/tjkade/Desktop/website-screenshots-2026-09-27"
        try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
        }

        func tapTab(_ title: String) {
            let id = app.buttons["tab-\(title.lowercased())"]
            if id.waitForExistence(timeout: 4) { id.tap(); return }
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 4) { tab.tap(); return }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 6), "Missing tab \(title)")
            btn.tap()
        }

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: 25)
                || app.buttons["tab-play"].waitForExistence(timeout: 2)
                || app.buttons["Play"].waitForExistence(timeout: 2),
            "tabs after seed sign-in"
        )
        sleep(2)

        // Optional supporting Play home
        let dismiss = app.buttons["Dismiss ad"].firstMatch
        if dismiss.waitForExistence(timeout: 2) { dismiss.tap(); sleep(1) }
        try snap("juicd-play-home")

        tapTab("Tourney")
        sleep(2)
        let dismiss2 = app.buttons["Dismiss ad"].firstMatch
        if dismiss2.waitForExistence(timeout: 2) { dismiss2.tap(); sleep(1) }

        // Scroll to reveal bracket if needed
        let bracket = app.staticTexts["Bracket"]
        if !bracket.waitForExistence(timeout: 3) {
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
        }
        // Prefer a frame that shows the bracket tree
        if bracket.exists {
            // nudge so Bracket card is prominent
            app.swipeUp()
            sleep(1)
        }
        try snap("juicd-tourney-bracket")

        // Also keep a full-page-ish second angle
        app.swipeUp()
        sleep(1)
        try snap("juicd-tourney-bracket-scrolled")
    }
}
