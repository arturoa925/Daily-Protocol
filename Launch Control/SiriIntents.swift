
import AppIntents
import SwiftData
import Foundation


// Cached so repeated Siri/Shortcuts resolutions in the same process session
// don't pay the cost of rebuilding the container each time.
private enum IntentContainer {
    static var shared: ModelContainer?

    static func get() throws -> ModelContainer {
        if let existing = shared { return existing }
        let schema = Schema([Event.self])
        let appGroupID = "group.AA.Launch-Control"
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            config = ModelConfiguration(schema: schema, url: groupURL.appendingPathComponent("LaunchControl.store"))
        } else {
            config = ModelConfiguration(schema: schema)
        }
        let container = try ModelContainer(for: schema, configurations: [config])
        shared = container
        return container
    }
}

private func makeContainer() throws -> ModelContainer {
    try IntentContainer.get()
}



struct AddTodayEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Event for Today"
    static var description = IntentDescription("Add a new event to today in Launch Control")
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var eventTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeContainer()
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
    // Called by AppIntents to resolve entities by ID — used for both
   
    func entities(for identifiers: [UUID]) async throws -> [EventEntity] {
        let context = ModelContext(try makeContainer())
        // Capture as local constant so #Predicate closes over a plain value
        let ids = identifiers
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                ids.contains(event.eventID)
            }
        )
        return try context.fetch(descriptor)
            .map { EventEntity(id: $0.eventID, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        let context = ModelContext(try makeContainer())
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= start && $0.date < end && !$0.isCompleted },
            sortBy: [SortDescriptor(\.date)]
        )
        let events = try context.fetch(descriptor)
        return events.map { EventEntity(id: $0.eventID, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }
    }

    // Called when Siri/Shortcuts resolves a spoken or typed name to an entity.
    // Supports partial, case-insensitive matches so "meet" finds "Team Meeting".
    func entities(matching string: String) async throws -> [EventEntity] {
        let context = ModelContext(try makeContainer())
        let all = try context.fetch(FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
        let query = string.lowercased()
        return all
            .filter { $0.title.lowercased().contains(query) }
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
        let context = ModelContext(try makeContainer())
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



struct TodaysEventsIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Events"
    static var description = IntentDescription("List all events scheduled for today in Launch Control")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try makeContainer())
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
