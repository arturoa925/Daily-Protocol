//
//  AddEventSheet.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI

struct AddEventSheet: View {
    @Binding var title: String
    @Binding var hasReminder: Bool
    @Binding var reminderDate: Date

    var onCancel: () -> Void
    var onSave: () -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTitleLabel: String {
        trimmedTitle.isEmpty ? "No title entered" : trimmedTitle
    }

    private var reminderStatusLabel: String {
        hasReminder ? "Reminder on" : "Reminder off"
    }

    private var reminderTimeLabel: String {
        reminderDate.formatted(date: .omitted, time: .shortened)
    }

    private var saveButtonHint: String {
        trimmedTitle.isEmpty
            ? "Enter an event title to enable saving"
            : "Saves this event"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .accessibilityLabel("Event title")
                        .accessibilityValue(normalizedTitleLabel)
                        .accessibilityHint("Enter a name for this event")
                        .accessibilitySortPriority(3)

                    Text("Give this event a short, clear name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Give this event a short, clear name.")
                } header: {
                    Text("Event")
                }

                Section {
                    Toggle("Add Reminder", isOn: $hasReminder)
                        .accessibilityLabel("Add reminder")
                        .accessibilityValue(reminderStatusLabel)
                        .accessibilityHint("Turns the reminder time on or off")
                        .accessibilitySortPriority(2)

                    if hasReminder {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderDate,
                            displayedComponents: .hourAndMinute
                        )
                        .accessibilityLabel("Reminder time")
                        .accessibilityValue(reminderTimeLabel)
                        .accessibilityHint("Adjust to set the reminder time")
                        .accessibilitySortPriority(2)
                    }

                    Text("You can save this event with or without a reminder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("You can save this event with or without a reminder.")
                } header: {
                    Text("Reminder")
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityElement(children: .contain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes this screen without saving your event")
                        .accessibilitySortPriority(1)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .accessibilityLabel("Save event")
                        .accessibilityValue(normalizedTitleLabel)
                        .accessibilityHint(saveButtonHint)
                        .accessibilitySortPriority(1)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var title = ""
    @Previewable @State var hasReminder = true
    @Previewable @State var reminderDate = Date()

    return AddEventSheet(
        title: $title,
        hasReminder: $hasReminder,
        reminderDate: $reminderDate,
        onCancel: {},
        onSave: {}
    )
}
