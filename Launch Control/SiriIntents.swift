
import AppIntents
import SwiftData
import Foundation


// Actor-isolated container cache — safely callable from any async context,
// including the nonisolated EntityQuery/EntityStringQuery protocol methods
// that AppIntents invokes outside the main actor.
private actor IntentContainer {
    static let shared = IntentContainer()
    private var container: ModelContainer?

    func get() throws -> ModelContainer {
        if let existing = container { return existing }
        let schema = Schema([Event.self])
        let appGroupID = "group.AA.Launch-Control"
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            config = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("LaunchControl.store"))
        } else {
            config = ModelConfiguration(schema: schema)
        }
        let fresh = try ModelContainer(for: schema, configurations: [config])
        container = fresh
        return fresh
    }
}



struct AddTodayEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Event for Today"
    static var description = IntentDescription("Add a new event to today in Launch Control")
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var eventTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try await IntentContainer.shared.get()
        let context = ModelContext(container)
        let event = Event(title: eventTitle, date: Date())
        context.insert(event)
        try context.save()
        return .result(dialog: "Added \"\(eventTitle)\" to today in Launch Control.")
    }
}



struct EventEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
    static var defaultQuery = EventQuery()

    var id: UUID
    var title: String
    var date: Date
    var isCompleted: Bool

    init(id: UUID, title: String, date: Date, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
    }

    var displayRepresentation: DisplayRepresentation {
        let dateString = date.formatted(.dateTime.month(.abbreviated).day().year())
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(dateString)"
        )
    }
}

struct EventQuery: EntityQuery, EntityStringQuery {

    // One equality query per identifier with fetchLimit 1 — more reliable than
    // array.contains in #Predicate, and SQLite short-circuits after the first match.
    func entities(for identifiers: [UUID]) async throws -> [EventEntity] {
        let context = ModelContext(try await IntentContainer.shared.get())
        return try identifiers.compactMap { uuid in
            var descriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { $0.eventID == uuid }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map {
                EventEntity(id: $0.eventID, title: $0.title, date: $0.date, isCompleted: $0.isCompleted)
            }
        }
    }

    // Siri shows ~6 items in the picker — cap at 10 so we don't over-fetch.
    func suggestedEntities() async throws -> [EventEntity] {
        let context = ModelContext(try await IntentContainer.shared.get())
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= start && $0.date < end && !$0.isCompleted },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 10
        let events = try context.fetch(descriptor)
        return events.map { EventEntity(id: $0.eventID, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }
    }

    // In-memory string filter — SwiftData predicates don't support case-insensitive
    // contains reliably, so we fetch sorted and filter in Swift. Cap output at 20
    // so Siri's disambiguation list stays usable.
    func entities(matching string: String) async throws -> [EventEntity] {
        let context = ModelContext(try await IntentContainer.shared.get())
        let all = try context.fetch(FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
        let query = string.lowercased()
        return all
            .filter { $0.title.lowercased().contains(query) }
            .prefix(20)
            .map { EventEntity(id: $0.eventID, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }
    }
}



struct MarkEventCompleteIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Event Complete"
    static var description = IntentDescription("Mark a today's event as completed in Launch Control")
    static var openAppWhenRun = false

    @Parameter(title: "Event")
    var event: EventEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // ModelContext is intentionally created fresh each call — it's lightweight.
        // The expensive ModelContainer is cached via IntentContainer.
        let context = ModelContext(try await IntentContainer.shared.get())
        let ids = [event.id]
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { ids.contains($0.eventID) }
        )
        guard let match = try context.fetch(descriptor).first else {
            throw $event.needsValueError("That event wasn't found.")
        }
        if match.isCompleted {
            return .result(dialog: "\"\(match.title)\" is already marked as complete.")
        }
        match.isCompleted = true
        try context.save()
        return .result(dialog: "Marked \"\(match.title)\" as complete.")
    }
}



struct RemoveTodayEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Event"
    static var description = IntentDescription("Delete an event from Launch Control")
    static var openAppWhenRun = false

    @Parameter(title: "Event", requestValueDialog: "Which event do you want to remove?")
    var event: EventEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try await IntentContainer.shared.get())
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.eventID == event.id }
        )
        descriptor.fetchLimit = 1
        guard let match = try context.fetch(descriptor).first else {
            throw $event.needsValueError("That event wasn't found.")
        }
        let title = match.title
        context.delete(match)
        try context.save()
        return .result(dialog: "Removed \"\(title)\" from Launch Control.")
    }
}



struct TodaysEventsIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Events"
    static var description = IntentDescription("List all events scheduled for today in Launch Control")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try await IntentContainer.shared.get())
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return .result(dialog: "Couldn't determine today's events.")
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        let all = try context.fetch(descriptor)

        if all.isEmpty {
            return .result(dialog: "You have no events scheduled for today.")
        }

        let total = all.count

        // Cap at 10 to keep the dialog concise
        let cap = 10
        let truncated = total > cap
        let shown = Array(all.prefix(cap))
        let shownPending = shown.filter { !$0.isCompleted }
        let shownDone    = shown.filter {  $0.isCompleted }

        func list(_ events: [Event]) -> String {
            let names = events.map { $0.title }
            switch names.count {
            case 1: return names[0]
            case 2: return "\(names[0]) and \(names[1])"
            default:
                return names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
            }
        }

        let eventWord = total == 1 ? "event" : "events"
        var parts: [String] = []

        if !shownPending.isEmpty {
            let word = shownPending.count == 1 ? "event" : "events"
            parts.append("\(shownPending.count) pending \(word): \(list(shownPending))")
        }
        if !shownDone.isEmpty {
            let word = shownDone.count == 1 ? "event" : "events"
            parts.append("\(shownDone.count) completed \(word): \(list(shownDone))")
        }

        let summary = truncated
            ? "You have \(total) \(eventWord) today — showing the first \(cap). "
            : "You have \(total) \(eventWord) today. "

        let detail = parts.joined(separator: ". ")
        let trailer = truncated ? " Open the app to see all \(total)." : ""

        return .result(dialog: "\(summary)\(detail).\(trailer)")
    }
}



struct LaunchControlShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodayEventIntent(),
            phrases: [
                "Add event for today in \(.applicationName)",
                "New event today in \(.applicationName)"
            ],
            shortTitle: "Add Today's Event",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: MarkEventCompleteIntent(),
            phrases: [
                "Mark event complete in \(.applicationName)",
                "Complete event in \(.applicationName)",
                "Mark \(\.$event) done in \(.applicationName)"
            ],
            shortTitle: "Complete Event",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: RemoveTodayEventIntent(),
            phrases: [
                "Remove event in \(.applicationName)",
                "Delete event in \(.applicationName)",
                "Remove \(\.$event) in \(.applicationName)"
            ],
            shortTitle: "Remove Event",
            systemImageName: "trash"
        )
        AppShortcut(
            intent: TodaysEventsIntent(),
            phrases: [
                "Show today's events in \(.applicationName)",
                "What's on my schedule in \(.applicationName)",
                "What do I have today in \(.applicationName)"
            ],
            shortTitle: "Today's Events",
            systemImageName: "calendar"
        )
    }
}
