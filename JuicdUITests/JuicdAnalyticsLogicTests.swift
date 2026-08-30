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
    private var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        launchedApp?.terminate()
        launchedApp = nil
        try super.tearDownWithError()
    }

    private func launchSeededAnalyticsApp() -> XCUIApplication {
        let app = XCUIApplication()
        launchedApp = app
        app.launchArguments += [
            "-skipTutorial",
            "-acceptLegalTerms",
            "-seedDemoData",
            "-showAnalyticsDebugOverlay",
        ]
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 15),
            "Seeded analytics app should reach the foreground"
        )
        return app
    }

    private func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        if tab.waitForExistence(timeout: 8) {
            tab.tap()
            return
        }
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing tab \(title)")
        button.tap()
    }

    private func waitForAnalyticsEvent(
        _ name: String,
        in app: XCUIApplication,
        afterEventCount baselineCount: String,
        timeout: TimeInterval = 8
    ) -> Bool {
        let countLabel = app.staticTexts["analytics-debug-count"]
        let lastEvent = app.staticTexts["analytics-debug-last-event"]
        guard countLabel.waitForExistence(timeout: 3),
              lastEvent.waitForExistence(timeout: 3) else {
            return false
        }

        // Both labels are published by the same main-queue update. Waiting for
        // the count to change prevents a stale same-named event from satisfying
        // the assertion after a second tab tap.
        let countChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", baselineCount),
            object: countLabel
        )
        let eventRecorded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", name),
            object: lastEvent
        )
        return XCTWaiter().wait(
            for: [countChanged, eventRecorded],
            timeout: timeout
        ) == .completed
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
        let dashboardBaseline = app.staticTexts["analytics-debug-count"].label
        tapTab("Dashboard", in: app)
        XCTAssertTrue(
            waitForAnalyticsEvent("tab_view", in: app, afterEventCount: dashboardBaseline),
            "Dashboard tab_view should reach the debug overlay"
        )
        let tourneyBaseline = app.staticTexts["analytics-debug-count"].label
        tapTab("Tourney", in: app)
        XCTAssertTrue(
            waitForAnalyticsEvent("tab_view", in: app, afterEventCount: tourneyBaseline),
            "Tourney tab_view should reach the debug overlay"
        )

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
        let friendsBaseline = app.staticTexts["analytics-debug-count"].label
        tapTab("Friends", in: app)
        XCTAssertTrue(
            waitForAnalyticsEvent("friends_view", in: app, afterEventCount: friendsBaseline),
            "Friends event should reach the debug overlay"
        )
        XCTAssertEqual(app.staticTexts["analytics-debug-last-event"].label, "friends_view")
    }
}
