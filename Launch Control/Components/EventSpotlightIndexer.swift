import CoreSpotlight
import Foundation
import SwiftData

/// Keeps Spotlight's index of events in step with the database, so typing an event's
/// title in Spotlight finds it. Failures are swallowed: search is a convenience,
/// and an indexing hiccup must never break adding or removing an event.
enum EventSpotlightIndexer {
    /// How far around today to index. Keeps the index small and relevant.
    static let daysBack = 7
    static let daysAhead = 60
    static let maxEvents = 200

    static func index(_ events: [Event]) async {
        guard !events.isEmpty else { return }
        try? await CSSearchableIndex.default().indexAppEntities(events.map(EventEntity.init))
    }

    static func remove(ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: ids, ofType: EventEntity.self)
    }

    /// Re-indexes the window of events around today. Called at launch and when the app
    /// goes to the background, which also picks up events added inside the app.
    static func reindexUpcoming(in container: ModelContainer, now: Date = Date()) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -daysBack, to: today),
              let end = calendar.date(byAdding: .day, value: daysAhead, to: today) else { return }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = maxEvents
        guard let events = try? context.fetch(descriptor) else { return }
        await index(events)
    }
}
