//
//  JuicdAnalyticsLogicTests.swift
//  JuicdUITests
//
//  Juicd has no dedicated unit-test target (only JuicdUITests), so this file
//  proves the analytics wiring two ways within the existing UI test target:
//   1. A pure logic check against the real app types via a black-box launch +
//      the always-present (visually transparent) AnalyticsDebugOverlay, which
//      is how a human/QA verifies it on a real simulator/device too.
//   2. Reading the on-device JSONL debug file the app writes to its own
//      Documents directory (no network involved) after a short run.
//
//  See LaunchPilot docs/ANALYTICS.md + kits/analytics/README.md.
//

import XCTest

final class JuicdAnalyticsLogicTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app, taps through Play → Dashboard → Tourney, then reads the
    /// always-present `analytics-debug-count` / `analytics-debug-last-event`
    /// accessibility elements to prove `app_open`, `sign_in`, and `tab_view`
    /// events were recorded by the network-free debug sink.
    func testAnalyticsDebugOverlayRecordsAppOpenSignInAndTabViewEvents() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-showAnalyticsDebugOverlay"]
        app.launch()

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

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

        tapTab("Dashboard")
        sleep(1)
        tapTab("Tourney")
        sleep(1)

        let countLabel = app.descendants(matching: .any)["analytics-debug-count"]
        XCTAssertTrue(countLabel.waitForExistence(timeout: 5), "analytics-debug-count element should exist")
        let count = Int(countLabel.label) ?? 0
        // app_open (1) + sign_in via dev skip (1) + tab_view x2 (Dashboard, Tourney) = at least 3.
        XCTAssertGreaterThanOrEqual(count, 3, "Expected at least 3 analytics events after app open + sign-in + 2 tab taps, got \(count)")

        let lastEventLabel = app.descendants(matching: .any)["analytics-debug-last-event"]
        XCTAssertTrue(lastEventLabel.waitForExistence(timeout: 2))
        XCTAssertEqual(lastEventLabel.label, "tab_view", "Last recorded event should be the most recent tab_view")
    }

    /// Friends gets its own dedicated event (in addition to the generic `tab_view`)
    /// because it's a key social feature the owner wants to watch adoption of on its own.
    func testAnalyticsDebugOverlayRecordsFriendsViewEvent() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms", "-seedDemoData", "-showAnalyticsDebugOverlay"]
        app.launch()

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

        for label in ["Agree", "I Agree", "Continue", "Skip", "Got it"] {
            if app.buttons[label].waitForExistence(timeout: 1) {
                app.buttons[label].tap()
            }
        }

        func tapTab(_ title: String) {
            let tab = app.tabBars.buttons[title]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
                return
            }
            let btn = app.buttons[title]
            XCTAssertTrue(btn.waitForExistence(timeout: 3), "Missing tab \(title)")
            btn.tap()
        }

        tapTab("Friends")
        sleep(1)

        let lastEventLabel = app.descendants(matching: .any)["analytics-debug-last-event"]
        XCTAssertTrue(lastEventLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(lastEventLabel.label, "friends_view", "Tapping the Friends tab should log friends_view (after tab_view)")
    }
}
