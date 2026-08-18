

import Foundation
import Testing
@testable import Launch_Control

struct EventDisplayTests {

    @Test func displayTitleUsesTimeWhenSet() {
        let calendar = Calendar.current
        let time = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let event = Event(title: "Meeting", date: Date(), time: time)

        let expectedTime = time.formatted(.dateTime.hour().minute())
        #expect(event.displayTitle == "Meeting — \(expectedTime)")
    }

    @Test func displayTitleUsesReminderDateWhenTimeIsNilButReminderIsSet() {
        let calendar = Calendar.current
        let reminderDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let event = Event(title: "Take out trash", date: Date(), reminderDate: reminderDate)

        let expectedTime = reminderDate.formatted(.dateTime.hour().minute())
        #expect(event.displayTitle == "Take out trash — \(expectedTime)")
    }

    @Test func displayTitleFallsBackToPlainTitleWhenNeitherIsSet() {
        let event = Event(title: "Just a title", date: Date())
        #expect(event.displayTitle == "Just a title")
    }

    @Test func displayTitlePrefersTimeOverReminderDateWhenBothAreSet() {
        let calendar = Calendar.current
        let time = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let reminderDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let event = Event(title: "Both set", date: Date(), time: time, reminderDate: reminderDate)

        let expectedTime = time.formatted(.dateTime.hour().minute())
        #expect(event.displayTitle == "Both set — \(expectedTime)")
    }
}
