import Foundation

/// Everything needed to rebuild a deleted event, so "undo" can bring it back.
struct EventSnapshot: Codable, Equatable {
    var eventID: UUID
    var title: String
    var date: Date
    var time: Date?
    var notes: String
    var category: String
    var isCompleted: Bool
    var hasReminder: Bool
    var reminderDate: Date?
    var createdAt: Date

    init(_ event: Event) {
        eventID = event.eventID
        title = event.title
        date = event.date
        time = event.time
        notes = event.notes
        category = event.category
        isCompleted = event.isCompleted
        hasReminder = event.hasReminder
        reminderDate = event.reminderDate
        createdAt = event.createdAt
    }

    func makeEvent() -> Event {
        Event(eventID: eventID, title: title, date: date, time: time, notes: notes,
              category: category, isCompleted: isCompleted, hasReminder: hasReminder,
              reminderDate: reminderDate, createdAt: createdAt)
    }
}

/// The last thing a Siri intent changed, which "undo" reverses.
enum UndoableAction: Codable, Equatable {
    case added(UUID)
    case completed(UUID)
    case removed(EventSnapshot)
}

/// Remembers only the most recent Siri action, and only for a short window, so a stray
/// "undo" an hour later can't unexpectedly delete something. Stored in the App Group
/// defaults because each intent runs in a fresh context.
struct LastActionStore {
    static let maxAge: TimeInterval = 10 * 60
    static let shared = LastActionStore(
        defaults: UserDefaults(suiteName: "group.AA.Launch-Control") ?? .standard
    )

    private struct Record: Codable {
        var action: UndoableAction
        var recordedAt: Date
    }

    let defaults: UserDefaults
    private let key = "lastUndoableAction"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func record(_ action: UndoableAction, at date: Date = Date()) {
        guard let data = try? JSONEncoder().encode(Record(action: action, recordedAt: date)) else { return }
        defaults.set(data, forKey: key)
    }

    /// Returns the last action if it is recent enough, and always clears it,
    /// so a second "undo" doesn't reverse something further back.
    func take(now: Date = Date()) -> UndoableAction? {
        defer { defaults.removeObject(forKey: key) }
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              now.timeIntervalSince(record.recordedAt) <= Self.maxAge else { return nil }
        return record.action
    }
}
