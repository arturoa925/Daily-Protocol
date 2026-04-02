//
//  AddCategorySheet.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI

struct AddCategorySheet: View {
    let categories: [String]
    @Binding var selection: String
    var onCancel: () -> Void
    var onSave: () -> Void

    private var normalizedSelectionLabel: String {
        selection.isEmpty ? "No category" : selection
    }

    private var availableCategoryCount: Int {
        categories.count + 1
    }

    private var saveButtonLabel: String {
        selection.isEmpty ? "Save without a category" : "Save category"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $selection) {
                        Text("No Category")
                            .tag("")
                            .accessibilityLabel("No category")
                            .accessibilityHint("Leaves this item without a category")
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                                .tag(category)
                                .accessibilityLabel(category)
                                .accessibilityHint("Selects the \(category) category")
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityLabel("Category")
                    .accessibilityValue(normalizedSelectionLabel)
                    .accessibilityHint("Choose one of \(availableCategoryCount) options")
                    .accessibilitySortPriority(2)

                    Text("Choose one category or leave this item uncategorized.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Choose one category or leave this item uncategorized.")
                } header: {
                    Text("Select a category")
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityElement(children: .contain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes this screen without saving your category selection")
                        .accessibilitySortPriority(3)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .accessibilityLabel(saveButtonLabel)
                        .accessibilityValue(normalizedSelectionLabel)
                        .accessibilityHint("Saves the current category selection")
                        .accessibilitySortPriority(3)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = "Work"
    return AddCategorySheet(
        categories: ["Work", "Health", "Education", "Personal", "Social"],
        selection: $selection,
        onCancel: {},
        onSave: {}
    )
}
