//
//  Launch_ControlTests.swift
//  Launch ControlTests
//
//  Created by Arturo Ayala on 3/17/26.
//

import Foundation
import Testing
@testable import Launch_Control

struct Launch_ControlTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
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
}
