//
//  EventEditingSheets.swift
//  Launch Control
//

import SwiftUI
import SwiftData

/// Bundles the add/notes/category sheets, the delete alert, and the notification-error
/// alert that every event-editing screen attaches identically.
struct EventEditingSheetsModifier: ViewModifier {
    @Bindable var editor: EventEditor
    let categories: [String]
    let modelContext: ModelContext
    let newEventDate: () -> Date

    private var notificationAlertBinding: Binding<Bool> {
        Binding(
            get: { editor.notificationErrorMessage != nil },
            set: { if !$0 { editor.notificationErrorMessage = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $editor.showAddEventSheet) {
                AddEventSheet(
                    title: $editor.eventTitle,
                    hasReminder: $editor.hasReminder,
                    reminderDate: $editor.reminderDate,
                    onCancel: { editor.showAddEventSheet = false },
                    onSave: { editor.saveNewEvent(date: newEventDate(), modelContext: modelContext) }
                )
            }
            .sheet(isPresented: $editor.showNotesSheet) {
                AddNotesSheet(
                    notes: $editor.noteDraft,
                    onCancel: editor.cancelNotesEditing,
                    onSave: editor.saveNotes
                )
            }
            .sheet(isPresented: $editor.showCategorySheet) {
                AddCategorySheet(
                    categories: categories,
                    selection: $editor.categoryDraft,
                    onCancel: editor.cancelCategoryEditing,
                    onSave: editor.saveCategory
                )
            }
            .deleteEventAlert(pendingDeletion: $editor.eventPendingDeletion) { event in
                editor.delete(event, from: modelContext)
            }
            .alert("Notification Issue", isPresented: notificationAlertBinding) {
                Button("OK", role: .cancel) {
                    editor.notificationErrorMessage = nil
                }
                .accessibilityLabel("OK")
                .accessibilityHint("Dismisses the notification issue message")
                .accessibilitySortPriority(1)
            } message: {
                Text(editor.notificationErrorMessage ?? "")
            }
    }
}

extension View {
    func eventEditingSheets(
        editor: EventEditor,
        categories: [String],
        modelContext: ModelContext,
        newEventDate: @escaping () -> Date
    ) -> some View {
        modifier(
            EventEditingSheetsModifier(
                editor: editor,
                categories: categories,
                modelContext: modelContext,
                newEventDate: newEventDate
            )
        )
    }
}
