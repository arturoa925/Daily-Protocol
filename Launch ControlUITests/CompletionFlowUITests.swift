
import XCTest

final class CompletionFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWeeklyMonthlyToggleSwitchesTheHeaderAndBack() throws {
        let app = XCUIApplication.launchedFresh()
        XCTAssertTrue(app.staticTexts["Events for today"].waitForExistence(timeout: 5))

        // Both headers consolidate into one accessibility element
        // (`.accessibilityElement(children: .ignore)`) whose label is lowercase and
        // doesn't match the visible heading text, so lookups go through the same
        // broad `row(containing:)`-style search used for accessibility-hidden rows
        // elsewhere, rather than `app.staticTexts[...]` with the rendered string.
        let weeklyHeader = app.row(containing: "Progress this week")
        app.swipeUp(until: weeklyHeader)
        XCTAssertTrue(weeklyHeader.exists, "Should reach the Completion screen, starting on the weekly view")

        // Tapped by coordinate: the toggle button's accessibility frame doesn't line
        // up with a reliably queryable, hittable element immediately after paging in
        // in this suite's simulator environment (a render-timing quirk seen
        // repeatedly with this pager during development, not specific to this test).
        
        // init the monthly view
        let monthlyHeader = app.row(containing: "Progress over 4 weeks")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.90)).tap()
        // checks first to make sure monthly view works
        XCTAssertTrue(monthlyHeader.waitForExistence(timeout: 3), "Toggling should switch to the monthly view")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.90)).tap()
        XCTAssertTrue(weeklyHeader.waitForExistence(timeout: 3), "Toggling again should switch back to the weekly view")
    }
}
