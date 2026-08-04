//
//  NotificationDelegate.swift
//  Launch Control
//

import Foundation
import SwiftData
import UserNotifications

final class EventNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.actionIdentifier == NotificationScheduler.markCompleteActionIdentifier,
              let eventID = UUID(uuidString: response.notification.request.identifier) else { return }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.eventID == eventID })
        guard let event = try? context.fetch(descriptor).first else { return }

        event.isCompleted = true
        try? context.save()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
