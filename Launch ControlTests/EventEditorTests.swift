

import Foundation
import SwiftData
import Testing
@testable import Launch_Control

// Serialized: concurrent @Test functions each creating their own in-memory
// ModelContainer(for: Event.self, ...) triggered an intermittent crash in
// makeContext() when run alongside the UI test target in a full-scheme run.
@Suite(.serialized)
struct EventEditorTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Event.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - saveNewEvent
    // Only exercised with hasReminder = false: true would call through to the live
    // UNUserNotificationCenter authorization flow, which can hang a unit test host
    // on a system permission prompt.

    @Test func saveNewEventInsertsATrimmedTitleAndClosesTheSheet() throws {
        let context = try makeContext()
        let editor = EventEditor()
        editor.eventTitle = "  Buy milk  "
        editor.hasReminder = false
        editor.showAddEventSheet = true

        let day = Date()
        editor.saveNewEvent(date: day, modelContext: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 1)
        #expect(events.first?.title == "Buy milk")
        #expect(events.first?.date == day)
        #expect(events.first?.reminderDate == nil)
        #expect(editor.showAddEventSheet == false)
    }

    @Test func saveNewEventWithoutReminderLeavesReminderDateNil() throws {
        let context = try makeContext()
        let editor = EventEditor()
        editor.eventTitle = "No reminder"
        editor.hasReminder = false
        editor.reminderDate = Date() // set, but should be ignored since hasReminder is false

        editor.saveNewEvent(date: Date(), modelContext: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.first?.hasReminder == false)
        #expect(events.first?.reminderDate == nil)
    }

    // MARK: - notes editing

    @Test func presentNotesPopulatesDraftFromTheEventAndShowsTheSheet() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), notes: "existing notes")

        editor.presentNotes(for: event)

        #expect(editor.selectedEvent === event)
        #expect(editor.noteDraft == "existing notes")
        #expect(editor.showNotesSheet == true)
    }

    @Test func cancelNotesEditingClearsAllNotesState() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), notes: "existing notes")
        editor.presentNotes(for: event)

        editor.cancelNotesEditing()

        #expect(editor.showNotesSheet == false)
        #expect(editor.selectedEvent == nil)
        #expect(editor.noteDraft == "")
    }

    @Test func saveNotesTrimsAndAssignsToTheSelectedEvent() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date())
        editor.presentNotes(for: event)
        editor.noteDraft = "  trimmed please  "

        editor.saveNotes()

        #expect(event.notes == "trimmed please")
        #expect(editor.showNotesSheet == false)
        #expect(editor.selectedEvent == nil)
        #expect(editor.noteDraft == "")
    }

    // MARK: - category editing

    @Test func presentCategoryPopulatesDraftFromTheEventAndShowsTheSheet() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), category: "Work")

        editor.presentCategory(for: event)

        #expect(editor.selectedEvent === event)
        #expect(editor.categoryDraft == "Work")
        #expect(editor.showCategorySheet == true)
    }

    @Test func cancelCategoryEditingClearsAllCategoryState() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), category: "Work")
        editor.presentCategory(for: event)

        editor.cancelCategoryEditing()

        #expect(editor.showCategorySheet == false)
        #expect(editor.selectedEvent == nil)
        #expect(editor.categoryDraft == "")
    }

    @Test func saveCategoryAssignsToTheSelectedEvent() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date())
        editor.presentCategory(for: event)
        editor.categoryDraft = "Health"

        editor.saveCategory()

        #expect(event.category == "Health")
        #expect(editor.showCategorySheet == false)
        #expect(editor.selectedEvent == nil)
        #expect(editor.categoryDraft == "")
    }

    // MARK: - delete
    // Exercised with nil, past, and future reminderDate to cover
    // removePendingNotification's guard branches; removing pending requests doesn't
    // require notification authorization, so this is safe to call live.

    @Test func deleteRemovesTheEventWithNoReminder() throws {
        let context = try makeContext()
        let editor = EventEditor()
        let event = Event(title: "A", date: Date())
        context.insert(event)

        editor.delete(event, from: context)

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
    }

    @Test func deleteRemovesTheEventWithAPastReminder() throws {
        let context = try makeContext()
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), reminderDate: Date().addingTimeInterval(-3600))
        context.insert(event)

        editor.delete(event, from: context)

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
    }

    @Test func deleteRemovesTheEventWithAFutureReminder() throws {
        let context = try makeContext()
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), reminderDate: Date().addingTimeInterval(3600))
        context.insert(event)

        editor.delete(event, from: context)

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
    }

    // MARK: - toggleCompletion

    @Test func toggleCompletionFlipsIsCompleted() {
        let editor = EventEditor()
        let event = Event(title: "A", date: Date(), isCompleted: false)

        editor.toggleCompletion(for: event)
        #expect(event.isCompleted == true)

        editor.toggleCompletion(for: event)
        #expect(event.isCompleted == false)
    }
}
