

import Foundation

enum CompletionCalculator {
    /// The 7 day-start dates of the week containing `referenceDate`.
    static func weekDays(calendar: Calendar = .current, referenceDate: Date = Date()) -> [Date] {
        guard let firstDay = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        ) else {
            return []
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay)
        }
    }

    /// The 4 consecutive week-start dates ending with the week containing `referenceDate`.
    static func lastFourWeekStarts(calendar: Calendar = .current, referenceDate: Date = Date()) -> [Date] {
        guard let currentWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        ) else {
            return []
        }

        return (0..<4).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -(3 - offset), to: currentWeekStart)
        }
    }

    /// Events falling on the same calendar day as `day`.
    static func events(_ events: [Event], onDay day: Date, calendar: Calendar = .current) -> [Event] {
        events.filter { event in
            calendar.isDate(event.date, inSameDayAs: day)
        }
    }

    /// Events falling within the 7-day window starting at `weekStart`.
    static func events(_ events: [Event], inWeekStartingAt weekStart: Date, calendar: Calendar = .current) -> [Event] {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        return events.filter { event in
            event.date >= weekStart && event.date < weekEnd
        }
    }

    static func completedCount(_ events: [Event]) -> Int {
        events.filter(\.isCompleted).count
    }
}
