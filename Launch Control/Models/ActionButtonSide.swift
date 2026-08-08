//
//  ActionButtonSide.swift
//  Launch Control
//

import SwiftUI

enum ActionButtonSide: String, CaseIterable, Identifiable {
    case trailing
    case leading

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trailing: return "Right"
        case .leading: return "Left"
        }
    }

    var alignment: Alignment {
        switch self {
        case .trailing: return .bottomTrailing
        case .leading: return .bottomLeading
        }
    }

    var edge: Edge.Set {
        switch self {
        case .trailing: return .trailing
        case .leading: return .leading
        }
    }
}
