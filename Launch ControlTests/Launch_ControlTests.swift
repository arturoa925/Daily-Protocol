

import Foundation
import Testing
@testable import Launch_Control

struct Launch_ControlTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

 
    private static func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static func date(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int = 12, minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func streakIsZeroWithNoCompletedEvents() {
        let calendar = Calendar.current
        let today = Date()
        let events = [Event(title: "A", date: today, isCompleted: false)]

        #expect(StreakCalculator.currentStreak(events: events, calendar: calendar, referenceDate: today) == 0)
    }

    @Test func streakCountsConsecutiveCompletedDaysEndingToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let events = [
            Event(title: "Today", date: today, isCompleted: true),
            Event(title: "Yesterday", date: yesterday, isCompleted: true),
            Event(title: "Two days ago", date: twoDaysAgo, isCompleted: true)
        ]

        #expect(StreakCalculator.currentStreak(events: events, calendar: calendar, referenceDate: today) == 3)
    }

    @Test func streakStopsAtAGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let events = [
            Event(title: "Today", date: today, isCompleted: true),
            Event(title: "Yesterday", date: yesterday, isCompleted: true),
            Event(title: "Three days ago", date: threeDaysAgo, isCompleted: true)
        ]

        #expect(StreakCalculator.currentStreak(events: events, calendar: calendar, referenceDate: today) == 2)
    }

    @Test func streakCarriesOverWhenTodayHasNoCompletionYet() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let events = [
            Event(title: "Today", date: today, isCompleted: false),
            Event(title: "Yesterday", date: yesterday, isCompleted: true),
            Event(title: "Two days ago", date: twoDaysAgo, isCompleted: true)
        ]

        #expect(StreakCalculator.currentStreak(events: events, calendar: calendar, referenceDate: today) == 2)
    }

    // MARK: - weekDays

    @Test func weekDaysReturnsSevenConsecutiveDaysStartingOnFirstWeekday() {
        let calendar = Self.fixedCalendar()
        // Wednesday, August 5 2026.
        let reference = Self.date(2026, 8, 5, calendar: calendar)

        let days = CompletionCalculator.weekDays(calendar: calendar, referenceDate: reference)

        #expect(days.count == 7)
        // Gregorian/en_US_POSIX weeks start on Sunday, so this week starts Aug 2.
        #expect(calendar.component(.weekday, from: days[0]) == calendar.firstWeekday)
        #expect(calendar.isDate(days[0], inSameDayAs: Self.date(2026, 8, 2, calendar: calendar)))
        #expect(calendar.isDate(days[6], inSameDayAs: Self.date(2026, 8, 8, calendar: calendar)))

        for (previous, next) in zip(days, days.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: previous, to: next).day == 1)
        }
    }

    @Test func weekDaysKeepsAWeekSpanningNewYearIntact() {
        let calendar = Self.fixedCalendar()
        // Thursday, Dec 31 2026 — its week runs Dec 27 2026 through Jan 2 2027.
        let reference = Self.date(2026, 12, 31, calendar: calendar)

        let days = CompletionCalculator.weekDays(calendar: calendar, referenceDate: reference)

        #expect(days.count == 7)
        #expect(calendar.isDate(days[0], inSameDayAs: Self.date(2026, 12, 27, calendar: calendar)))
        #expect(calendar.isDate(days[6], inSameDayAs: Self.date(2027, 1, 2, calendar: calendar)))
    }

    // MARK: - lastFourWeekStarts

    @Test func lastFourWeekStartsEndsWithTheReferenceWeek() {
        let calendar = Self.fixedCalendar()
        let reference = Self.date(2026, 8, 5, calendar: calendar)

        let weekStarts = CompletionCalculator.lastFourWeekStarts(calendar: calendar, referenceDate: reference)

        #expect(weekStarts.count == 4)
        // Reference week starts Aug 2; the three prior weeks start Jul 12, 19, 26.
        #expect(calendar.isDate(weekStarts[0], inSameDayAs: Self.date(2026, 7, 12, calendar: calendar)))
        #expect(calendar.isDate(weekStarts[3], inSameDayAs: Self.date(2026, 8, 2, calendar: calendar)))

        for (previous, next) in zip(weekStarts, weekStarts.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: previous, to: next).day == 7)
        }
    }

    // MARK: - CompletionCalculator day bucketing

    @Test func eventsOnDayIncludesLateNightAndExcludesAdjacentDays() {
        let calendar = Self.fixedCalendar()
        let day = Self.date(2026, 8, 5, calendar: calendar)

        let events = [
            Event(title: "Just before midnight", date: Self.date(2026, 8, 5, hour: 23, minute: 59, calendar: calendar)),
            Event(title: "Start of day", date: Self.date(2026, 8, 5, hour: 0, minute: 0, calendar: calendar)),
            Event(title: "Next day", date: Self.date(2026, 8, 6, hour: 0, minute: 1, calendar: calendar)),
            Event(title: "Previous day", date: Self.date(2026, 8, 4, hour: 23, minute: 59, calendar: calendar))
        ]

        let matched = CompletionCalculator.events(events, onDay: day, calendar: calendar)

        #expect(matched.count == 2)
        #expect(matched.allSatisfy { calendar.isDate($0.date, inSameDayAs: day) })
    }

    // MARK: - CompletionCalculator week-window bucketing

    @Test func eventsInWeekTreatsStartAsInclusiveAndEndAsExclusive() {
        let calendar = Self.fixedCalendar()
        let weekStart = Self.date(2026, 8, 2, hour: 0, minute: 0, calendar: calendar)

        let events = [
            Event(title: "Exactly at week start", date: weekStart),
            Event(title: "Mid week", date: Self.date(2026, 8, 5, calendar: calendar)),
            Event(title: "Last moment of week", date: Self.date(2026, 8, 8, hour: 23, minute: 59, calendar: calendar)),
            Event(title: "Exactly at next week start", date: Self.date(2026, 8, 9, hour: 0, minute: 0, calendar: calendar)),
            Event(title: "Before week", date: Self.date(2026, 8, 1, hour: 23, minute: 59, calendar: calendar))
        ]

        let matched = CompletionCalculator.events(events, inWeekStartingAt: weekStart, calendar: calendar)

        #expect(matched.count == 3)
        #expect(matched.contains { $0.title == "Exactly at week start" })
        #expect(matched.contains { $0.title == "Last moment of week" })
        #expect(!matched.contains { $0.title == "Exactly at next week start" })
        #expect(!matched.contains { $0.title == "Before week" })
    }

    // MARK: - CompletionCalculator.completedCount

    @Test func completedCountCountsOnlyCompletedEvents() {
        let calendar = Self.fixedCalendar()
        let day = Self.date(2026, 8, 5, calendar: calendar)

        let events = [
            Event(title: "A", date: day, isCompleted: true),
            Event(title: "B", date: day, isCompleted: false),
            Event(title: "C", date: day, isCompleted: true)
        ]

        #expect(CompletionCalculator.completedCount(events) == 2)
    }

    @Test func completedCountOfEmptyListIsZero() {
        #expect(CompletionCalculator.completedCount([]) == 0)
    }
}
