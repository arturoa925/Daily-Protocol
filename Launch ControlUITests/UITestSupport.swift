//
//  UITestSupport.swift
//  Launch ControlUITests
//

import XCTest

extension XCUIApplication {
    /// Launches a fresh instance with data and settings reset to defaults, so a test
    /// doesn't inherit state left over by an earlier run -- the SwiftData store and
    /// @AppStorage settings otherwise persist across separate test launches on the
    /// simulator.
    static func launchedFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        return app
    }

    /// Swipes up until `element` appears. A screen with a long scrollable list
    /// scrolls first and only pages once it reaches the bottom, so reaching a
    /// landmark further down the pager can take several swipes.
    func swipeUp(until element: XCUIElement, maxSwipes: Int = 12) {
        for _ in 0..<maxSwipes where !element.exists {
            swipeUp()
        }
    }

    /// Finds a row by its outer accessibility element's label rather than its inner
    /// text: rows built with `.accessibilityElement(children: .contain/.ignore)`
    /// don't expose their inner `Text` nodes to a direct `.staticTexts[...]` lookup.
    func row(containing text: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// Protocol's and Calendar's "Add event" buttons share the same label, and (a
    /// known, separate, pre-existing leak) each stays in the accessibility tree even
    /// when its own screen isn't visible. Calendar's button carries a date
    /// accessibility value; Protocol's doesn't -- so that's how the two are told
    /// apart, rather than picking whichever the query happens to list first.
    func addEventButton(requiringDateValue: Bool) -> XCUIElement? {
        let candidates = buttons.matching(NSPredicate(format: "label == 'Add event'"))
        for index in 0..<candidates.count {
            let candidate = candidates.element(boundBy: index)
            let hasValue = !(candidate.value as? String ?? "").isEmpty
            if hasValue == requiringDateValue {
                return candidate
            }
        }
        return nil
    }
}
