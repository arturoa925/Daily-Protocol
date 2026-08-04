//
//  AppColor.swift
//  Launch Control
//

import SwiftUI

extension Color {
    // App Background, App Surface, and Text Primary are provided by Xcode's generated
    // asset symbols (Assets.xcassets) — no manual declaration needed here.

    // Fixed brand colors for data visualization — intentionally not theme-adaptive so the
    // completion charts read consistently regardless of light/dark appearance.
    static let chartBarBottom = Color(hex: 0x1D3772)
    static let chartBarTop = Color(hex: 0x3868D8)
    static let chartAccentLine = Color(hex: 0x3FD2F3)
}
