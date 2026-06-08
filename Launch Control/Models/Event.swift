//
//  Event.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import Foundation
import SwiftData


@Model
final class Event {
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

    init(
        eventID: UUID = UUID(),
        title: String,
        date: Date,
        time: Date? = nil,
        notes: String = "",
        category: String = "",
        isCompleted: Bool = false,
        hasReminder: Bool = false,
        reminderDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.eventID = eventID
        self.title = title
        self.date = date
        self.time = time
        self.notes = notes
        self.category = category
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
        self.reminderDate = reminderDate
        self.createdAt = createdAt
    }
}
