

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppearanceSelectionPersistsAcrossRelaunch() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 3))
        app.buttons["Dark"].tap()
        app.buttons["Done"].tap()

        // Relaunched deliberately without the reset flag, to pick up what the first
        // launch just persisted to @AppStorage rather than wiping it again.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.wait(for: .runningForeground, timeout: 5), "App should be running in the foreground after relaunch")

        XCTAssertTrue(relaunched.staticTexts["Events for today"].waitForExistence(timeout: 5))
        relaunched.buttons["Settings"].tap()

        let darkOptionAfterRelaunch = relaunched.buttons["Dark"]
        XCTAssertTrue(darkOptionAfterRelaunch.waitForExistence(timeout: 3))
        XCTAssertTrue(darkOptionAfterRelaunch.isSelected, "Dark should still be the selected option after relaunch")
    }

    @MainActor
    func testActionButtonSideMovesTheFloatingAddButton() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        guard let addButtonBefore = app.addEventButton(requiringDateValue: false) else {
            XCTFail("Should find Protocol's own Add event button")
            return
        }
        let rightSideX = addButtonBefore.frame.minX

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Left"].waitForExistence(timeout: 3))
        app.buttons["Left"].tap()
        app.buttons["Done"].tap()

        guard let addButtonAfter = app.addEventButton(requiringDateValue: false) else {
            XCTFail("Should still find Protocol's own Add event button after moving it")
            return
        }
        let leftSideX = addButtonAfter.frame.minX

        XCTAssertLessThan(leftSideX, rightSideX, "Add button should have moved from the right edge to the left")
    }
}
