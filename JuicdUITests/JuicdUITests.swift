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
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData"]
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
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                return
            }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 3), "Missing tab \(title)")
            btn.tap()
        }

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

        // Legal / tutorial leftovers
        for label in ["Agree", "I Agree", "Continue", "Skip", "Got it"] {
            if app.buttons[label].waitForExistence(timeout: 1) {
                app.buttons[label].tap()
            }
        }

        let playTab = app.tabBars.buttons["Play"]
        let playBtn = app.buttons["Play"]
        XCTAssertTrue(
            playTab.waitForExistence(timeout: 12) || playBtn.waitForExistence(timeout: 2),
            "Tab bar should appear after dev skip sign-in"
        )

        sleep(2)
        try snap("01-play")

        tapTab("Dashboard")
        sleep(2)
        try snap("04-dashboard")

        tapTab("Tourney")
        sleep(2)
        let simulate = app.buttons["Simulate full bracket (demo)"]
        if simulate.waitForExistence(timeout: 2) {
            simulate.tap()
            sleep(2)
        }
        try snap("03-tourney")

        tapTab("Friends")
        sleep(2)
        try snap("05-friends")

        tapTab("Profile")
        sleep(2)
        try snap("06-profile")
    }

    /// Cloud anonymous sign-in (no `-seedDemoData`) — asserts Friends shows a real friend code.
    func testAnonymousCloudFriendCodeScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms"]
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
}
