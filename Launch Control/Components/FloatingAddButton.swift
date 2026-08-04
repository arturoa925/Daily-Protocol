//
//  FloatingAddButton.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI

struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)

                        Circle()
                            .fill(Color.blue.opacity(0.5))

                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                )
                .shadow(color: Color.blue.opacity(0.25), radius: 12, x: 0, y: 6)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 4)
                )
                .scaleEffect(1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add event")
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Color.black.ignoresSafeArea()
        FloatingAddButton(action: {})
            .padding(24)
    }
}
