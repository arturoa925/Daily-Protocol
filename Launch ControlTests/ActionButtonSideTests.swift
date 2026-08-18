

import SwiftUI
import Testing
@testable import Launch_Control

struct ActionButtonSideTests {

    @Test func trailingMapsToTheRightSideLabelAlignmentAndEdge() {
        let side = ActionButtonSide.trailing
        #expect(side.label == "Right")
        #expect(side.alignment == .bottomTrailing)
        #expect(side.edge == .trailing)
    }

    @Test func leadingMapsToTheLeftSideLabelAlignmentAndEdge() {
        let side = ActionButtonSide.leading
        #expect(side.label == "Left")
        #expect(side.alignment == .bottomLeading)
        #expect(side.edge == .leading)
    }

    @Test func idMatchesRawValueForEveryCase() {
        for side in ActionButtonSide.allCases {
            #expect(side.id == side.rawValue)
        }
    }

    @Test func rawValueRoundTripsForEveryCase() {
        for side in ActionButtonSide.allCases {
            #expect(ActionButtonSide(rawValue: side.rawValue) == side)
        }
    }
}
