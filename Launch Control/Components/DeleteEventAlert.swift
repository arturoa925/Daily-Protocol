//
//  DeleteEventAlert.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI

struct DeleteEventAlertModifier: ViewModifier {
    @Binding var pendingDeletion: Event?
    var onDelete: (Event) -> Void

    func body(content: Content) -> some View {
        content
            .alert("Delete Event?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let event = pendingDeletion {
                        onDelete(event)
                        pendingDeletion = nil
                    }
                }
                .accessibilityLabel("Delete event")
                .accessibilityHint("Permanently removes this event from your schedule")
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Closes this alert without deleting the event")
            } message: {
                Text("This event will be removed from your schedule.")
                    .accessibilityLabel("This event will be removed from your schedule")
            }
    }
}

extension View {
    func deleteEventAlert(pendingDeletion: Binding<Event?>, onDelete: @escaping (Event) -> Void) -> some View {
        self.modifier(DeleteEventAlertModifier(pendingDeletion: pendingDeletion, onDelete: onDelete))
    }
}
