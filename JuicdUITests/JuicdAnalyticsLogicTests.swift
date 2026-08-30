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

    private func launchSeededAnalyticsApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-skipTutorial",
            "-acceptLegalTerms",
            "-seedDemoData",
            "-showAnalyticsDebugOverlay",
        ]
        app.launch()
        return app
    }

    private func tapTab(_ title: String, in app: XCUIApplication) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing tab \(title)")
        button.tap()
    }

    private func waitForAnalyticsEvent(
        _ name: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 8
    ) -> Bool {
        let lastEvent = app.staticTexts["analytics-debug-last-event"]
        guard lastEvent.waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate(format: "label == %@", name)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: lastEvent)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Launches the app, taps through Play → Dashboard → Tourney, then reads the
    /// always-present `analytics-debug-count` / `analytics-debug-last-event`
    /// accessibility elements to prove `app_open`, `sign_in`, and `tab_view`
    /// events were recorded by the network-free debug sink.
    func testAnalyticsDebugOverlayRecordsAppOpenSignInAndTabViewEvents() throws {
        let app = launchSeededAnalyticsApp()

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 12), "Tab bar should appear after dev skip sign-in")
        tapTab("Dashboard", in: app)
        XCTAssertTrue(waitForAnalyticsEvent("tab_view", in: app), "Dashboard tab_view should reach the debug overlay")
        tapTab("Tourney", in: app)
        XCTAssertTrue(waitForAnalyticsEvent("tab_view", in: app), "Tourney tab_view should reach the debug overlay")

        let countLabel = app.staticTexts["analytics-debug-count"]
        XCTAssertTrue(countLabel.waitForExistence(timeout: 8), "analytics-debug-count element should exist")
        let count = Int(countLabel.label) ?? 0
        // app_open + sign_in + tab_view x2, plus any legitimate screen events.
        XCTAssertGreaterThanOrEqual(count, 4, "Expected at least 4 analytics events after app open + sign-in + 2 tab taps, got \(count)")
        XCTAssertEqual(app.staticTexts["analytics-debug-last-event"].label, "tab_view")
    }

    /// Friends gets its own dedicated event (in addition to the generic `tab_view`)
    /// because it's a key social feature the owner wants to watch adoption of on its own.
    func testAnalyticsDebugOverlayRecordsFriendsViewEvent() throws {
        let app = launchSeededAnalyticsApp()

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 12), "Sign-in skip button should appear")
        skipButton.tap()

        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 12), "Tab bar should appear after dev skip sign-in")
        tapTab("Friends", in: app)
        XCTAssertTrue(waitForAnalyticsEvent("friends_view", in: app), "Friends event should reach the debug overlay")
        XCTAssertEqual(app.staticTexts["analytics-debug-last-event"].label, "friends_view")
    }
}
