//
//  EventEditor.swift
//  Launch Control
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// Owns the add/notes/category/delete editing state shared by every screen that
/// lets the user create or modify an Event, so that plumbing isn't duplicated per screen.
@Observable
final class EventEditor {
    static let defaultCategories = ["Work", "Health", "Education", "Personal", "Social"]

    var showAddEventSheet = false
    var eventTitle = ""
    var hasReminder = false
    var reminderDate = Date()
    var notificationErrorMessage: String?

    var showNotesSheet = false
    var selectedEvent: Event?
    var noteDraft = ""

    var showCategorySheet = false
    var categoryDraft = ""

    var eventPendingDeletion: Event?

    func prepareForNewEvent(defaultReminderDate: Date) {
        eventTitle = ""
        hasReminder = false
        reminderDate = defaultReminderDate
        showAddEventSheet = true
    }

    func saveNewEvent(date: Date, modelContext: ModelContext) {
        let trimmedTitle = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminder = hasReminder ? reminderDate : nil

        let newEvent = Event(
            title: trimmedTitle,
            date: date,
            time: nil,
            notes: "",
            category: "",
            hasReminder: hasReminder,
            reminderDate: reminder
        )

        modelContext.insert(newEvent)

        if let reminder {
            NotificationScheduler.scheduleNotification(
                for: newEvent.eventID.uuidString,
                title: trimmedTitle,
                reminderDate: reminder
            ) { [weak self] error in
                if let error {
                    DispatchQueue.main.async {
                        self?.notificationErrorMessage = error.localizedDescription
                    }
                }
            }
        }

        showAddEventSheet = false
    }

    func toggleCompletion(for event: Event) {
        withAnimation(.easeInOut(duration: 0.22)) {
            event.isCompleted.toggle()
        }
    }

    func presentNotes(for event: Event) {
        selectedEvent = event
        noteDraft = event.notes
        showNotesSheet = true
    }

    func cancelNotesEditing() {
        showNotesSheet = false
        selectedEvent = nil
        noteDraft = ""
    }

    func saveNotes() {
        selectedEvent?.notes = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        showNotesSheet = false
        selectedEvent = nil
        noteDraft = ""
    }

    func presentCategory(for event: Event) {
        selectedEvent = event
        categoryDraft = event.category
        showCategorySheet = true
    }

    func cancelCategoryEditing() {
        showCategorySheet = false
        selectedEvent = nil
        categoryDraft = ""
    }

    func saveCategory() {
        selectedEvent?.category = categoryDraft
        showCategorySheet = false
        selectedEvent = nil
        categoryDraft = ""
    }

    func delete(_ event: Event, from context: ModelContext) {
        event.removePendingNotification()
        context.delete(event)
    }
}
