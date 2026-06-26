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
        app.launchArguments += ["-skipTutorial", "-acceptLegalTerms"]
        app.launch()

        let outputDir = "/Users/tjkade/Desktop/juicd/qa-screenshots"
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        func snap(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }

        func tapTab(_ title: String) {
            app.buttons[title].tap()
        }

        let skipButton = app.buttons["Skip — local dev account"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "Sign-in skip button should appear")
        try snap("sign-in")
        skipButton.tap()

        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "Tab bar should appear after dev skip sign-in")

        if app.buttons["Skip"].waitForExistence(timeout: 2) {
            app.buttons["Skip"].tap()
        }

        sleep(1)
        try snap("play")

        tapTab("Dashboard")
        sleep(1)
        try snap("dashboard")

        tapTab("Tourney")
        sleep(1)
        try snap("tourney")

        tapTab("Friends")
        sleep(1)
        try snap("friends")

        tapTab("Profile")
        sleep(1)
        try snap("profile")
    }
}
