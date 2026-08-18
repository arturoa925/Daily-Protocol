//
//  AppearanceModeTests.swift
//  Launch ControlTests
//

import SwiftUI
import Testing
@testable import Launch_Control

struct AppearanceModeTests {

    @Test func systemMapsToNilColorSchemeAndItsLabel() {
        let mode = AppearanceMode.system
        #expect(mode.label == "System")
        #expect(mode.colorScheme == nil)
    }

    @Test func lightMapsToTheLightColorSchemeAndItsLabel() {
        let mode = AppearanceMode.light
        #expect(mode.label == "Light")
        #expect(mode.colorScheme == .light)
    }

    @Test func darkMapsToTheDarkColorSchemeAndItsLabel() {
        let mode = AppearanceMode.dark
        #expect(mode.label == "Dark")
        #expect(mode.colorScheme == .dark)
    }

    @Test func idMatchesRawValueForEveryCase() {
        for mode in AppearanceMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test func rawValueRoundTripsForEveryCase() {
        for mode in AppearanceMode.allCases {
            #expect(AppearanceMode(rawValue: mode.rawValue) == mode)
        }
    }
}
