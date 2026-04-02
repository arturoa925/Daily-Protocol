//
//  NotificationScheduler.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    static func scheduleNotification(for eventID: String, title: String, reminderDate: Date, completion: @escaping (Error?) -> Void) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, authError in
            if let authError {
                completion(authError)
                return
            }

            guard granted else {
                let error = NSError(domain: "NotificationScheduler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications are turned off. Please allow notifications for Launch Control in Settings."])
                completion(error)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Reminder from Launch Control"
            content.sound = .default

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            // when to send notif
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            // the package sent in notif
            let request = UNNotificationRequest(identifier: eventID, content: content, trigger: trigger)

            center.add(request) { addError in
                completion(addError)
            }
        }
    }
}
