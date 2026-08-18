//
//  CalendarFlowUITests.swift
//  Launch ControlUITests
//

import XCTest

final class CalendarFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddingAnEventShowsItOnTheSelectedDay() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        let datePicker = app.datePickers.firstMatch
        app.swipeUp(until: datePicker)
        XCTAssertTrue(datePicker.exists, "Should reach the Calendar screen")

        // Tapped by coordinate, not via element lookup: floating buttons on a pager
        // screen reached by swiping (rather than the initial page) have proven
        // unreliable to tap by element reference during development, the same issue
        // that required a coordinate tap for the Completion toggle button.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.90)).tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Dentist appointment")
        app.buttons["Save event"].tap()

        XCTAssertTrue(
            app.row(containing: "Dentist appointment").waitForExistence(timeout: 3),
            "New event should appear on the selected day after saving"
        )
    }
}
