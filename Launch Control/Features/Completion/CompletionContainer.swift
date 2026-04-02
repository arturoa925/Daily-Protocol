//
//  CompletionContainer.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/25/26.
//

import SwiftUI

struct CompletionContainerView: View {
    enum Mode {
        case week
        case month
    }

    @State private var mode: Mode = .week

    var body: some View {
        ZStack {
            switch mode {
            case .week:
                WeeklyCompletionView(
                    onShowMonth: {
                        mode = .month
                    }
                )

            case .month:
                MonthlyCompletionView(
                    onShowWeek: {
                        mode = .week
                    }
                )
            }
        }
    }
}
