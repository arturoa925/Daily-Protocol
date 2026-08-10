//
//  Event+Display.swift
//  Launch Control
//

import Foundation
import UserNotifications

extension Event {
    var displayTitle: String {
        if let time {
            let formattedTime = time.formatted(.dateTime.hour().minute())
            return "\(title) — \(formattedTime)"
        }

        if let reminderDate {
            let formattedReminder = reminderDate.formatted(.dateTime.hour().minute())
            return "\(title) — \(formattedReminder)"
        }

        return title
    }

    func removePendingNotification() {
        guard let reminderDate, reminderDate > Date() else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [eventID.uuidString])
    }
}
