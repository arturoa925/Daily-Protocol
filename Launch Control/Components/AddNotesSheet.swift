//
//  AddNotesSheet.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI

struct AddNotesSheet: View {
    @Binding var notes: String
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add Notes")
                    .font(.headline)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilitySortPriority(3)

                TextEditor(text: $notes)
                    .padding(8)
                    .frame(minHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityLabel("Notes")
                    .accessibilityValue(notes.isEmpty ? "No notes entered" : notes)
                    .accessibilityHint("Enter notes or use dictation")
                    .accessibilitySortPriority(2)
            }
            .padding()
            .navigationTitle("Notes")
            .accessibilityElement(children: .contain)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes this screen without saving your notes")
                        .accessibilitySortPriority(1)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .accessibilityLabel("Save notes")
                        .accessibilityValue(notes.isEmpty ? "No notes entered" : "Notes added")
                        .accessibilityHint("Saves the notes you entered")
                        .accessibilitySortPriority(1)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var notes = "Notes for your protocol..."
    return AddNotesSheet(notes: $notes, onCancel: {}, onSave: {})
}
