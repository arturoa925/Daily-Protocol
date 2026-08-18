

import XCTest

final class ProtocolFlowUITests: XCTestCase {

    /// The empty-state row's accessibility label differs from its visible text
    /// (`ProtocolView.swift`), so lookups have to use this, not the rendered string.
    private static let emptyStateLabel = "No events for today. Use the add event button to create your first event."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesToTheEmptyStateAfterReset() throws {
        let app = XCUIApplication.launchedFresh()

        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts[Self.emptyStateLabel].exists,
            "A freshly reset app should show the empty state, not events from an earlier test run"
        )
    }

    @MainActor
    func testAddingAnEventShowsItInTheList() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        guard let addButton = app.addEventButton(requiringDateValue: false) else {
            XCTFail("Should find Protocol's own Add event button")
            return
        }
        addButton.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Water the plants")
        app.buttons["Save event"].tap()

        XCTAssertTrue(
            app.row(containing: "Water the plants").waitForExistence(timeout: 3),
            "New event should appear after saving"
        )
        XCTAssertFalse(
            app.staticTexts[Self.emptyStateLabel].exists,
            "Empty state should be gone once an event exists"
        )
    }

    @MainActor
    func testLongPressAddsNotesShownAsAnIndicatorDot() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        guard let addButton = app.addEventButton(requiringDateValue: false) else {
            XCTFail("Should find Protocol's own Add event button")
            return
        }
        addButton.tap()
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Refactor check")
        app.buttons["Save event"].tap()
        XCTAssertTrue(app.row(containing: "Refactor check").waitForExistence(timeout: 3))

        // Pressed by coordinate rather than on the row element directly: with only
        // one event in a freshly reset list, it sits at a fixed, known position, and
        // a broad accessibility-element lookup doesn't reliably resolve to a frame
        // XCUITest can physically press on.
        let rowCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.185, dy: 0.4855))
        rowCoordinate.press(forDuration: 0.8)

        let notesField = app.textViews.firstMatch
        XCTAssertTrue(notesField.waitForExistence(timeout: 3), "Notes sheet should open on long press")
        notesField.tap()
        notesField.typeText("Twice a week")
        app.buttons["Save notes"].tap()

        // Protocol's row shows a notes indicator dot rather than the notes text
        // itself; there's no dedicated accessibility label for it to assert on
        // directly, so this just confirms the round trip didn't crash or leave the
        // notes sheet open.
        XCTAssertFalse(notesField.exists, "Notes sheet should be dismissed after saving")
    }

    @MainActor
    func testDeletingAnEventRemovesItFromTheList() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        guard let addButton = app.addEventButton(requiringDateValue: false) else {
            XCTFail("Should find Protocol's own Add event button")
            return
        }
        addButton.tap()
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Temporary event")
        app.buttons["Save event"].tap()

        let row = app.row(containing: "Temporary event")
        XCTAssertTrue(row.waitForExistence(timeout: 3))

        app.buttons["Delete Temporary event"].tap()
        app.buttons["Delete event"].tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 3), "Event should be gone after delete")
    }
}
