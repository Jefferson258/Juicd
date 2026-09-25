//
//  JuicdUITests.swift
//  JuicdUITests
//

import XCTest

final class JuicdUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVisualQAScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-ads-on", "-juicd-dev-signin"]
        app.launch()

        // Resolve repo/qa-screenshots from this source file (portable; no Desktop hardcode).
        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JuicdUITests/
            .deletingLastPathComponent() // juicd/
            .appendingPathComponent("qa-screenshots")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        func tapTab(_ title: String) {
            let identifierTab = app.buttons["tab-\(title.lowercased())"]
            if identifierTab.waitForExistence(timeout: 3) {
                identifierTab.tap()
                return
            }
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                return
            }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 3), "Missing tab \(title)")
            btn.tap()
        }

        // -juicd-dev-signin auto-loads seeded demo profile (Skip button removed from SignInView).
        let playTab = app.tabBars.buttons["Play"]
        let playBtn = app.buttons["Play"]
        let playId = app.buttons["tab-play"]
        XCTAssertTrue(
            playTab.waitForExistence(timeout: 20) || playBtn.waitForExistence(timeout: 2) || playId.waitForExistence(timeout: 2),
            "Tab bar should appear after -juicd-dev-signin"
        )

        sleep(2)
        _ = app.otherElements["ad-sponsored-card"].waitForExistence(timeout: 6)
        // Dismiss AdMob test banner before marketing/ASC snaps
        let dismissPlayAd = app.buttons["Dismiss ad"].firstMatch
        if dismissPlayAd.waitForExistence(timeout: 2) {
            dismissPlayAd.tap()
            sleep(1)
        }
        try snap("01-play")

        tapTab("Dashboard")
        sleep(2)
        try snap("04-dashboard")

        tapTab("Tourney")
        sleep(2)
        _ = app.otherElements["ad-sponsored-card"].waitForExistence(timeout: 6)
        let dismissTourneyAd = app.buttons["Dismiss ad"].firstMatch
        if dismissTourneyAd.waitForExistence(timeout: 2) {
            dismissTourneyAd.tap()
            sleep(1)
        }
        let simulate = app.buttons["Simulate full bracket (demo)"]
        if simulate.waitForExistence(timeout: 2) {
            simulate.tap()
            sleep(4)
        }
        try snap("03-tourney")

        tapTab("Friends")
        sleep(2)
        try snap("05-friends")

        tapTab("Profile")
        sleep(2)
        try snap("06-profile")
    }



    func testWebsiteFillInScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-ads-on", "-juicd-dev-signin"]
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        XCTAssertTrue(
            app.buttons["tab-dashboard"].waitForExistence(timeout: 20)
                || app.buttons["Dashboard"].waitForExistence(timeout: 5),
            "Expected tabs after dev sign-in"
        )

        let dash = app.buttons["tab-dashboard"]
        if dash.exists { dash.tap() } else { app.buttons["Dashboard"].tap() }
        sleep(2)

        // Top of Dashboard = Play slips (bet history) for website `bets` slot.
        XCTAssertTrue(app.staticTexts["Dashboard"].waitForExistence(timeout: 6) || app.staticTexts["Play slips"].waitForExistence(timeout: 2))
        sleep(1)
        try snap("website-bets")

        // Scroll to Rank ladder / MMR for website `mmrInfo` slot.
        for _ in 0..<4 { app.swipeUp(); sleep(0) }
        sleep(1)
        _ = app.staticTexts["Rank ladder"].waitForExistence(timeout: 2)
            || app.staticTexts["Rank tier"].waitForExistence(timeout: 1)
            || app.staticTexts["Current tier"].waitForExistence(timeout: 1)
        try snap("website-mmrInfo")
    }

    func testParlayScreenshot() throws {
        let app = XCUIApplication()
        // -juicd-dev-signin auto-loads seeded demo profile (Skip button removed from SignInView).
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-ads-on", "-juicd-dev-signin"]
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let playTab = app.tabBars.buttons["Play"]
        let playBtn = app.buttons["Play"]
        let playId = app.buttons["tab-play"]
        XCTAssertTrue(
            playTab.waitForExistence(timeout: 20) || playBtn.waitForExistence(timeout: 2) || playId.waitForExistence(timeout: 2),
            "Tab bar should appear after -juicd-dev-signin"
        )
        sleep(2)

        // Open slip from first Over control on the seeded stub board.
        let over = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Over")).element(boundBy: 0)
        XCTAssertTrue(over.waitForExistence(timeout: 10), "Expected Over button on Play board")
        over.tap()
        sleep(1)

        // Prefer a multi-leg Parlay sheet when possible.
        let addLeg = app.buttons["Add another pick (parlay)"]
        if addLeg.waitForExistence(timeout: 4) {
            addLeg.tap()
            sleep(1)
            let over2 = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Over")).element(boundBy: 1)
            if over2.waitForExistence(timeout: 6) {
                over2.tap()
            } else {
                let overFallback = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Over")).element(boundBy: 0)
                XCTAssertTrue(overFallback.waitForExistence(timeout: 4))
                overFallback.tap()
            }
            sleep(1)
        }

        // Sheet title is "Parlay" with 2+ legs, else "Place bet".
        let parlayNav = app.navigationBars["Parlay"]
        let placeBetNav = app.navigationBars["Place bet"]
        XCTAssertTrue(
            parlayNav.waitForExistence(timeout: 6) || placeBetNav.waitForExistence(timeout: 2),
            "ParlayBuilderSheet should be visible"
        )
        sleep(1)

        let data = XCUIScreen.main.screenshot().pngRepresentation
        try data.write(to: URL(fileURLWithPath: "\(outputDir)/02-parlay.png"))
    }

    /// Cloud anonymous sign-in (no `-seedDemoData`) — asserts Friends shows a real friend code.
    func testAnonymousCloudFriendCodeScreenshot() throws {
        let stagingURL = ProcessInfo.processInfo.environment["JUICD_STAGING_SUPABASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stagingKey = ProcessInfo.processInfo.environment["JUICD_STAGING_SUPABASE_ANON_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try XCTSkipUnless(
            !stagingURL.isEmpty && !stagingKey.isEmpty,
            "Cloud UI test requires explicit staging Supabase URL and anon key"
        )
        try XCTSkipUnless(
            !stagingURL.contains("hwyxtklbffqwcbtuetit.supabase.co"),
            "Cloud UI test refuses the production Supabase project"
        )

        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms"]
        app.launchEnvironment["JUICD_TEST_SUPABASE_URL"] = stagingURL
        app.launchEnvironment["JUICD_TEST_SUPABASE_ANON_KEY"] = stagingKey
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func tapTab(_ title: String) {
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 2) {
                tab.tap()
                return
            }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 5), "Missing tab \(title)")
            btn.tap()
        }

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

        for label in ["Agree", "I Agree", "Continue", "Skip", "Got it"] {
            if app.buttons[label].waitForExistence(timeout: 1) {
                app.buttons[label].tap()
            }
        }

        // Custom tab bar (not UITabBar) — match visual-QA helper.
        let playTab = app.tabBars.buttons["Play"]
        let playBtn = app.buttons["Play"]
        XCTAssertTrue(
            playTab.waitForExistence(timeout: 20) || playBtn.waitForExistence(timeout: 20),
            "Tab bar should appear after cloud sign-in"
        )

        tapTab("Friends")
        sleep(2)

        // Prefer identifier; fall back to card title if accessibility wiring differs.
        let byId = app.descendants(matching: .any)["friend-code"]
        let byTitle = app.staticTexts["Your friend code"]
        let appeared = byId.waitForExistence(timeout: 25) || byTitle.waitForExistence(timeout: 2)

        let data = XCUIScreen.main.screenshot().pngRepresentation
        try data.write(to: URL(fileURLWithPath: "\(outputDir)/05-friends-cloud.png"))

        XCTAssertTrue(appeared, "Friends should show Your friend code after anonymous Supabase sign-in")
        if byId.exists {
            XCTAssertGreaterThanOrEqual(byId.label.count, 4, "Friend code should be non-trivial")
        }
    }

    func testPolishUIScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-dev-signin"]
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots/polish-2026-09-25")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        func tapTab(_ title: String) {
            let identifierTab = app.buttons["tab-\(title.lowercased())"]
            if identifierTab.waitForExistence(timeout: 3) {
                identifierTab.tap()
                return
            }
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                return
            }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 3), "Missing tab \(title)")
            btn.tap()
        }

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: 20)
                || app.buttons["tab-play"].waitForExistence(timeout: 2)
                || app.buttons["Play"].waitForExistence(timeout: 2),
            "Expected tabs after -juicd-dev-signin"
        )
        sleep(2)

        let dismissPlayAd = app.buttons["Dismiss ad"].firstMatch
        if dismissPlayAd.waitForExistence(timeout: 3), dismissPlayAd.isHittable {
            dismissPlayAd.tap()
            sleep(1)
        }
        try snap("10-play-board")

        // Prefer moneyline / H2H if present on board for label QA.
        let h2h = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Head-to-head")).element(boundBy: 0)
        if h2h.waitForExistence(timeout: 2) {
            try snap("11-play-h2h")
        }

        let over = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Over")).element(boundBy: 0)
        XCTAssertTrue(over.waitForExistence(timeout: 10), "Expected Over on Play board")
        over.tap()
        sleep(1)

        let addLeg = app.buttons["Add another pick (parlay)"]
        XCTAssertTrue(addLeg.waitForExistence(timeout: 6), "Expected Add another pick")
        addLeg.tap()
        sleep(1)
        // Board should show grayed invalid tiles while picking an additional leg.
        try snap("12-parlay-invalid-gray")

        // Finish a second leg if possible, then leave the sheet.
        let over2 = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Over")).element(boundBy: 1)
        if over2.waitForExistence(timeout: 4) {
            over2.tap()
            sleep(1)
            try snap("13-parlay-sheet")
            let close = app.navigationBars.buttons["Close"]
            if close.waitForExistence(timeout: 2) {
                close.tap()
                sleep(1)
            } else if app.buttons["Close"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Close"].firstMatch.tap()
                sleep(1)
            }
        } else {
            let cancel = app.buttons["Cancel"]
            if cancel.waitForExistence(timeout: 2) { cancel.tap(); sleep(1) }
        }

        tapTab("Tourney")
        sleep(2)
        let dismissTourneyAd = app.buttons["Dismiss ad"].firstMatch
        if dismissTourneyAd.waitForExistence(timeout: 3) {
            dismissTourneyAd.tap()
            sleep(1)
        }
        try snap("14-tourney-toggles")

        tapTab("Profile")
        sleep(2)
        for _ in 0..<8 { app.swipeUp(); sleep(0) }
        sleep(1)
        try snap("15-profile-delete-bottom")
    }


    func testPolishTourneyProfileScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-dev-signin"]
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots/polish-2026-09-25")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        func tapTab(_ title: String) {
            let identifierTab = app.buttons["tab-\(title.lowercased())"]
            if identifierTab.waitForExistence(timeout: 3) { identifierTab.tap(); return }
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 3) { tab.tap(); return }
            app.buttons[title].tap()
        }

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: 20)
                || app.buttons["tab-play"].waitForExistence(timeout: 2)
                || app.buttons["Play"].waitForExistence(timeout: 2)
        )
        sleep(2)

        tapTab("Tourney")
        sleep(2)
        let dismiss = app.buttons["Dismiss ad"].firstMatch
        if dismiss.waitForExistence(timeout: 3), dismiss.isHittable {
            dismiss.tap(); sleep(1)
        }
        // Tap Weekly then Daily to exercise polished toggles.
        if app.buttons["Weekly"].waitForExistence(timeout: 3) {
            app.buttons["Weekly"].tap(); sleep(1)
            try snap("14-tourney-weekly")
            if app.buttons["Daily"].waitForExistence(timeout: 2) {
                app.buttons["Daily"].tap(); sleep(1)
            }
        }
        try snap("14-tourney-toggles")

        tapTab("Profile")
        sleep(2)
        for _ in 0..<10 { app.swipeUp() }
        sleep(1)
        try snap("15-profile-delete-bottom")
    }


    func testCardCompactScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-dev-signin"]
        app.launch()

        let outputDir = "/tmp/juicd-card-compact-qa"
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: 20)
                || app.buttons["tab-play"].waitForExistence(timeout: 2)
                || app.buttons["Play"].waitForExistence(timeout: 2),
            "Expected tabs after -juicd-dev-signin"
        )
        sleep(2)

        let dismissPlayAd = app.buttons["Dismiss ad"].firstMatch
        if dismissPlayAd.waitForExistence(timeout: 3), dismissPlayAd.isHittable {
            dismissPlayAd.tap()
            sleep(1)
        }
        try snap("10-play-popular")

        let mlb = app.buttons["MLB"]
        if mlb.waitForExistence(timeout: 4) {
            mlb.tap()
            sleep(2)
            try snap("20-mlb-grid")
        }

        let allFilter = app.buttons["All"]
        if allFilter.waitForExistence(timeout: 3) {
            allFilter.tap()
            sleep(1)
            try snap("21-mlb-all-h2h")
        }

        let nfl = app.buttons["NFL"]
        if nfl.waitForExistence(timeout: 3) {
            nfl.tap()
            sleep(2)
            if app.buttons["All"].waitForExistence(timeout: 2) {
                app.buttons["All"].tap()
                sleep(1)
            }
            try snap("30-nfl-grid")
        }

        let h2h = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Head-to-head")).element(boundBy: 0)
        if h2h.waitForExistence(timeout: 3) {
            try snap("11-play-h2h")
        }

        try snap("99-left-running")
    }


    func testCFBPlayScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-juicd-ads-on", "-juicd-dev-signin"]
        app.launch()

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("qa-screenshots/cfb-2026-09-25")
            .path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let playTab = app.tabBars.buttons["Play"]
        XCTAssertTrue(playTab.waitForExistence(timeout: 20) || app.buttons["tab-play"].waitForExistence(timeout: 2))
        sleep(2)
        let dismiss = app.buttons["Dismiss ad"].firstMatch
        if dismiss.waitForExistence(timeout: 2) { dismiss.tap(); sleep(1) }

        // CFB sport pill
        let cfb = app.buttons["CFB"].firstMatch
        XCTAssertTrue(cfb.waitForExistence(timeout: 8), "CFB pill should appear on Play")
        cfb.tap()
        sleep(1)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try data.write(to: URL(fileURLWithPath: "\(outputDir)/12-cfb-selected-uitest.png"))
    }
}
