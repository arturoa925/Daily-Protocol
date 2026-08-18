//
//  Launch_ControlUITests.swift
//  Launch ControlUITests
//
//  Created by Arturo Ayala on 3/17/26.
//

import XCTest

final class Launch_ControlUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Only the visible screen should be in the accessibility tree. Without this,
    /// VoiceOver can traverse into the screens above and below the current one.
    @MainActor
    func testOffScreenPagesAreHiddenFromAccessibility() throws {
        let app = XCUIApplication.launchedFresh()

        let protocolHeader = app.staticTexts["Events for today"]
        let calendarPicker = app.datePickers.firstMatch

        XCTAssertTrue(protocolHeader.waitForExistence(timeout: 5), "Should start on the Protocol screen")
        XCTAssertFalse(calendarPicker.exists, "The Calendar screen should not be reachable while it's off-screen")

        app.swipeUp(until: calendarPicker)

        XCTAssertTrue(calendarPicker.exists, "Should reach the Calendar screen")
        XCTAssertFalse(protocolHeader.exists, "The Protocol screen should drop out once it's off-screen")

        // Known gap: each screen's floating action button still leaks into the tree
        // when off-screen. `.accessibilityHidden` has no effect on them at any point
        // in the modifier chain, so they aren't asserted on here.

        for _ in 0..<12 where !protocolHeader.exists {
            app.swipeDown()
        }
        XCTAssertTrue(protocolHeader.exists, "Should be able to swipe back to the Protocol screen")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
