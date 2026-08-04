//
//  StreakCalculator.swift
//  Launch Control
//

import Foundation

enum StreakCalculator {
    /// Number of consecutive days, ending at `referenceDate`, with at least one completed event.
    /// If `referenceDate` itself has no completions yet, the count starts from the day before —
    /// so the streak doesn't drop to 0 the moment a new day begins, before the user has acted.
    static func currentStreak(events: [Event], calendar: Calendar = .current, referenceDate: Date = Date()) -> Int {
        let completedDays = Set(
            events
                .filter(\.isCompleted)
                .map { calendar.startOfDay(for: $0.date) }
        )

        guard !completedDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: referenceDate)
        if !completedDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        return streak
    }
}
