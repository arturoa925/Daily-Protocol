import AppIntents
import Foundation
import SwiftData
import Testing
@testable import Launch_Control

/// Runs the real App Intents against the real shared SwiftData store, the same code path Siri uses.
/// Reminders are deliberately never requested (no times, no "remind me"): scheduling one
/// would call the live notification-permission flow, which can hang a unit test host.
///
/// Serialized because every test shares the one App Group store.
@Suite(.serialized)
struct IntentFlowTests {

    private func freshContext() async throws -> ModelContext {
        let context = ModelContext(try await IntentContainer.shared.get())
        try context.delete(model: Event.self)
        try context.save()
        _ = LastActionStore.shared.take()
        return context
    }

    private func allEvents(_ context: ModelContext) throws -> [Event] {
        try context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func insert(_ context: ModelContext, _ title: String, category: String = "", notes: String = "") throws -> Event {
        let event = Event(title: title, date: Date(), notes: notes, category: category)
        context.insert(event)
        try context.save()
        return event
    }

    // MARK: - Plan Something

    @Test func planSomethingFilesTheEventOnTheSpokenDay() async throws {
        let context = try await freshContext()
        var intent = AddEventFromSentenceIntent()
        intent.sentence = "dentist tomorrow"
        _ = try await intent.perform()

        let events = try allEvents(context)
        #expect(events.count == 1)
        #expect(events.first?.title.lowercased().contains("dentist") == true)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(Calendar.current.isDate(events[0].date, inSameDayAs: tomorrow))
    }

    @Test func planSomethingSplitsNotesOutOfTheSentence() async throws {
        let context = try await freshContext()
        var intent = AddEventFromSentenceIntent()
        intent.sentence = "Gym session tomorrow, leg day"
        _ = try await intent.perform()

        let event = try #require(try allEvents(context).first)
        #expect(event.title.lowercased().contains("gym"))
        #expect(event.notes.lowercased().contains("leg day"))
    }

    // MARK: - Undo

    @Test func undoRemovesTheEventJustAdded() async throws {
        let context = try await freshContext()
        var plan = AddEventFromSentenceIntent()
        plan.sentence = "Buy milk"
        _ = try await plan.perform()
        #expect(try allEvents(context).count == 1)

        _ = try await UndoLastActionIntent().perform()
        #expect(try allEvents(context).isEmpty)
    }

    @Test func undoReversesACompletion() async throws {
        let context = try await freshContext()
        let event = try insert(context, "Write report")
        var complete = MarkEventCompleteIntent()
        complete.event = EventEntity(event)
        _ = try await complete.perform()

        let afterComplete = ModelContext(try await IntentContainer.shared.get())
        #expect(try allEvents(afterComplete).first?.isCompleted == true)

        _ = try await UndoLastActionIntent().perform()
        let afterUndo = ModelContext(try await IntentContainer.shared.get())
        #expect(try allEvents(afterUndo).first?.isCompleted == false)
    }

    @Test func undoRestoresARemovedEventWithEveryDetail() async throws {
        let context = try await freshContext()
        let event = try insert(context, "Dentist", category: "Health", notes: "bring card")
        let originalID = event.eventID
        var remove = RemoveTodayEventIntent()
        remove.event = EventEntity(event)
        _ = try await remove.perform()
        #expect(try allEvents(ModelContext(try await IntentContainer.shared.get())).isEmpty)

        _ = try await UndoLastActionIntent().perform()
        let restored = try #require(try allEvents(ModelContext(try await IntentContainer.shared.get())).first)
        #expect(restored.eventID == originalID)
        #expect(restored.title == "Dentist")
        #expect(restored.category == "Health")
        #expect(restored.notes == "bring card")
    }

    @Test func undoWithNothingRecentChangesNothing() async throws {
        let context = try await freshContext()
        _ = try insert(context, "Untouched")
        _ = try await UndoLastActionIntent().perform()
        #expect(try allEvents(ModelContext(try await IntentContainer.shared.get())).count == 1)
    }

    @Test func undoIgnoresAnActionOlderThanTheWindow() async throws {
        let context = try await freshContext()
        let event = try insert(context, "Old news")
        let stale = Date().addingTimeInterval(-(LastActionStore.maxAge + 60))
        LastActionStore.shared.record(.added(event.eventID), at: stale)

        _ = try await UndoLastActionIntent().perform()
        #expect(try allEvents(ModelContext(try await IntentContainer.shared.get())).count == 1)
    }

    @Test func aSecondUndoDoesNotGoFurtherBack() async throws {
        let context = try await freshContext()
        var first = AddEventFromSentenceIntent()
        first.sentence = "First thing"
        _ = try await first.perform()
        var second = AddEventFromSentenceIntent()
        second.sentence = "Second thing"
        _ = try await second.perform()

        _ = try await UndoLastActionIntent().perform()
        _ = try await UndoLastActionIntent().perform()
        let remaining = try allEvents(ModelContext(try await IntentContainer.shared.get()))
        #expect(remaining.count == 1)
        #expect(remaining.first?.title.lowercased().contains("first") == true)
    }

    // MARK: - Reading and searching

    @Test func todaysEventsHandlesAMixOfDoneAndPending() async throws {
        let context = try await freshContext()
        let done = try insert(context, "Done thing")
        done.isCompleted = true
        _ = try insert(context, "Pending thing")
        try context.save()
        _ = try await TodaysEventsIntent().perform()
    }

    @Test func eventQueryFindsByTitleAndSuggestsOnlyOpenEventsToday() async throws {
        let context = try await freshContext()
        _ = try insert(context, "Dentist appointment")
        let done = try insert(context, "Finished already")
        done.isCompleted = true
        try context.save()

        let matches = try await EventQuery().entities(matching: "DENT")
        #expect(matches.map(\.title) == ["Dentist appointment"])
        let suggested = try await EventQuery().suggestedEntities()
        #expect(suggested.map(\.title) == ["Dentist appointment"])
    }

    @Test func askingWithoutAppleIntelligenceFailsSoftly() async throws {
        _ = try await freshContext()
        var ask = AskLaunchControlIntent()
        ask.question = "What should I do first?"
        _ = try await ask.perform() // must answer (or apologise) rather than throw
    }

    @Test func spotlightIndexingNeverThrowsOrBlocksTheFlow() async throws {
        let context = try await freshContext()
        let event = try insert(context, "Searchable")
        await EventSpotlightIndexer.index([event])
        await EventSpotlightIndexer.remove(ids: [event.eventID])
        await EventSpotlightIndexer.reindexUpcoming(in: try await IntentContainer.shared.get())
    }
}
