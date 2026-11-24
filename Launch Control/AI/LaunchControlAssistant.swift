import Foundation
import SwiftData
import FoundationModels

/// On-device intelligence for Launch Control, built on Apple's Foundation Models framework.
/// Everything runs locally on the Apple Intelligence model, so the app's
/// "no network calls, no data leaves the device" privacy promise still holds.
enum LaunchControlAssistant {

    /// Whether the system language model can be used right now.
    static var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Natural-language event capture

    /// Turns "dentist next Tuesday, bring insurance card" into a structured draft.
    /// Uses guided generation (`@Generable`), so the model returns typed fields
    /// instead of free text we'd have to parse. Falls back to `EventDraftParser`
    /// whenever the model is unavailable or errors, so capture always works.
    static func draftEvent(from sentence: String, now: Date = Date()) async -> EventDraft {
        guard isModelAvailable else { return EventDraftParser.parse(sentence, now: now) }

        let today = now.formatted(date: .complete, time: .omitted)
        let session = LanguageModelSession(instructions: """
            You turn a spoken request into one planner event. Today is \(today). \
            Express the day only as dayOffset, the number of days from today \
            (0 = today, 1 = tomorrow). Use hour and minute in 24-hour time only if the user stated a time, otherwise hour is -1. Never invent details the user did not say.
            """)
        do {
            let response = try await session.respond(to: sentence, generating: GeneratedEventDraft.self)
            let generated = response.content
            let draft = EventDraft(title: generated.title, dayOffset: generated.dayOffset,
                                   hour: generated.hour >= 0 ? generated.hour : nil, minute: generated.minute,
                                   category: generated.category, notes: generated.notes,
                                   wantsReminder: generated.wantsReminder)
            return draft.title.isEmpty ? EventDraftParser.parse(sentence, now: now) : draft
        } catch {
            return EventDraftParser.parse(sentence, now: now)
        }
    }

    // MARK: - Ask about your plan

    /// Answers a free-form question ("what should I tackle first?", "how's my week going?").
    /// The model can't see the database directly. It calls read-only tools, so its
    /// answer is grounded in real events and it has no ability to modify anything.
    static func answer(_ question: String, now: Date = Date()) async -> String {
        guard isModelAvailable else {
            return "Apple Intelligence isn't available right now, so I can't answer open questions. Try \"What do I have today\" instead."
        }

        let today = now.formatted(date: .complete, time: .omitted)
        let session = LanguageModelSession(
            tools: [EventsOnDayTool(), ProgressTool()],
            instructions: """
                You are the voice assistant for Launch Control, a daily planner. Today is \(today). \
                Always call a tool to look up events or progress before answering. \
                Reply in one to three short sentences that sound natural when spoken aloud: \
                no lists, no markdown. If there is nothing to report, say so plainly.
                """)
        do {
            return try await session.respond(to: question).content
        } catch {
            return "Sorry, I couldn't work that out. Try asking again, or say \"What do I have today\"."
        }
    }
}

// MARK: - Guided generation schema

@Generable
struct GeneratedEventDraft {
    @Guide(description: "Short event title of 2 to 6 words, without any date words")
    var title: String

    @Guide(description: "Days from today until the event: 0 is today, 1 is tomorrow", .range(0...365))
    var dayOffset: Int

    @Guide(description: "Hour of day in 24-hour time if the user stated a time, else -1", .range(-1...23))
    var hour: Int

    @Guide(description: "Minute of the hour, 0 if no time was stated", .range(0...59))
    var minute: Int

    @Guide(description: "Best-fitting category, or None", .anyOf(["Work", "Health", "Education", "Personal", "Social", "None"]))
    var category: String

    @Guide(description: "True only if the user asked to be reminded or notified")
    var wantsReminder: Bool

    @Guide(description: "Extra details the user mentioned, or an empty string")
    var notes: String
}

// MARK: - Read-only tools the model may call

struct EventsOnDayTool: Tool {
    let name = "eventsOnDay"
    let description = "Lists the planner events for one day with their completion status."

    @Generable
    struct Arguments {
        @Guide(description: "Days from today: 0 is today, 1 is tomorrow, -1 is yesterday", .range(-30...30))
        var dayOffset: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let context = ModelContext(try await IntentContainer.shared.get())
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: arguments.dayOffset, to: Date()),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
            return "Could not determine that day."
        }
        let start = calendar.startOfDay(for: day)
        let events = try context.fetch(FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        ))
        guard !events.isEmpty else { return "No events on that day." }
        return events.prefix(25).map { event in
            let category = event.category.isEmpty ? "" : " [\(event.category)]"
            return "- \(event.title)\(category): \(event.isCompleted ? "done" : "pending")"
        }.joined(separator: "\n")
    }
}

struct ProgressTool: Tool {
    let name = "progress"
    let description = "Returns the current streak and this week's completed versus total event counts."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let context = ModelContext(try await IntentContainer.shared.get())
        let all = try context.fetch(FetchDescriptor<Event>())
        let streak = StreakCalculator.currentStreak(events: all)

        let calendar = Calendar.current
        let week = CompletionCalculator.weekDays(calendar: calendar).first.map {
            CompletionCalculator.events(all, inWeekStartingAt: $0, calendar: calendar)
        } ?? []
        let done = CompletionCalculator.completedCount(week)
        return "Streak: \(streak) day(s). This week: \(done) of \(week.count) events completed."
    }
}
