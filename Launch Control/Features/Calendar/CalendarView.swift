//
//  CalendarView.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI
import SwiftData
import UserNotifications

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Event.date),
        SortDescriptor(\Event.createdAt)
    ]) private var events: [Event]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showAddEventSheet = false
    @State private var eventTitle = ""
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var notificationErrorMessage: String?

    @State private var swipedEventID: PersistentIdentifier?

    @State private var showNotesSheet = false
    @State private var showCategorySheet = false
    @State private var selectedEvent: Event?
    @State private var noteDraft = ""
    @State private var categoryDraft = ""
    @State private var eventPendingDeletion: Event?
    private let categories = ["Work", "Health", "Education", "Personal", "Social"]

    private var eventsForSelectedDate: [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var formattedSelectedDate: String {
        let weekday = selectedDate.formatted(.dateTime.weekday(.abbreviated))
        let day = selectedDate.formatted(.dateTime.day())
        let year = selectedDate.formatted(.dateTime.year())
        return "\(weekday) - \(day), \(year)"
    }

    private var selectedDateAccessibilityLabel: String {
        selectedDate.formatted(date: .complete, time: .omitted)
    }

    private var selectedDateSummaryLabel: String {
        let count = eventsForSelectedDate.count
        if count == 0 {
            return "No events"
        } else if count == 1 {
            return "1 event"
        } else {
            return "\(count) events"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground
                .ignoresSafeArea()

            PageScrollView(page: 1) {
                VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .tint(.blue)
                    .padding(8)
                    .accessibilityLabel("Calendar date")
                    .accessibilityValue(selectedDateAccessibilityLabel)
                    .accessibilityHint("Select a day to view events")
                    .accessibilitySortPriority(3)
                }
                .background(Color.appSurface)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)

                Text(formattedSelectedDate)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(selectedDateAccessibilityLabel)
                    .accessibilityValue(selectedDateSummaryLabel)
                    .accessibilitySortPriority(2)

                if eventsForSelectedDate.isEmpty {
                    Text("No events on this day. Tap + to add one.")
                        .font(.body)
                        .foregroundStyle(Color.textPrimary.opacity(0.8))
                        .padding(.top, 8)
                        .accessibilityLabel("No events on this day")
                        .accessibilityValue(selectedDateAccessibilityLabel)
                        .accessibilityHint("Use the add button to create a new event")
                        .accessibilitySortPriority(1)
                } else {
                    VStack(spacing: 12) {
                        ForEach(eventsForSelectedDate) { event in
                            eventRow(for: event)
                        }
                    }
                }
                }
                .padding()
                // Clears the floating add button so the last rows stay readable.
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            FloatingAddButton(action: {
                eventTitle = ""
                hasReminder = false
                // Default reminder time to selected day at 9 AM
                let calendar = Calendar.current
                reminderDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                showAddEventSheet = true
            })
            .accessibilityLabel("Add event")
            .accessibilityValue(selectedDateAccessibilityLabel)
            .accessibilityHint("Opens the sheet to create a new event for the selected date")
            .accessibilitySortPriority(1)
            .padding(24)
            .sheet(isPresented: $showAddEventSheet) {
                AddEventSheet(
                    title: $eventTitle,
                    hasReminder: $hasReminder,
                    reminderDate: $reminderDate,
                    onCancel: { showAddEventSheet = false },
                    onSave: {
                        let trimmedTitle = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let reminder = hasReminder ? reminderDate : nil

                        // Ensure the event's date is the selected day (start of day)
                        let day = Calendar.current.startOfDay(for: selectedDate)
                        let newEvent = Event(
                            title: trimmedTitle,
                            date: day,
                            time: nil,
                            notes: "",
                            category: "",
                            hasReminder: hasReminder,
                            reminderDate: reminder
                        )

                        modelContext.insert(newEvent)

                        if let reminder {
                            NotificationScheduler.scheduleNotification(for: newEvent.eventID.uuidString, title: trimmedTitle, reminderDate: reminder) { error in
                                if let error {
                                    DispatchQueue.main.async {
                                        notificationErrorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }

                        showAddEventSheet = false
                    }
                )
            }
            .sheet(isPresented: $showNotesSheet) {
                AddNotesSheet(
                    notes: $noteDraft,
                    onCancel: {
                        showNotesSheet = false
                        selectedEvent = nil
                        noteDraft = ""
                    },
                    onSave: {
                        selectedEvent?.notes = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        showNotesSheet = false
                        selectedEvent = nil
                        noteDraft = ""
                    }
                )
            }
            .sheet(isPresented: $showCategorySheet) {
                AddCategorySheet(
                    categories: categories,
                    selection: $categoryDraft,
                    onCancel: {
                        showCategorySheet = false
                        selectedEvent = nil
                        categoryDraft = ""
                    },
                    onSave: {
                        selectedEvent?.category = categoryDraft
                        showCategorySheet = false
                        selectedEvent = nil
                        categoryDraft = ""
                    }
                )
            }
            .deleteEventAlert(pendingDeletion: $eventPendingDeletion, onDelete: { event in
                deleteEvent(event)
            })
            .alert("Notification Issue", isPresented: Binding(
                get: { notificationErrorMessage != nil },
                set: { if !$0 { notificationErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    notificationErrorMessage = nil
                }
                .accessibilityLabel("OK")
                .accessibilityHint("Dismisses the notification issue message")
                .accessibilitySortPriority(1)
            } message: {
                Text(notificationErrorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func eventRow(for event: Event) -> some View {
        let completionActionName = event.isCompleted ? "Mark as not completed" : "Mark as completed"

        HStack(alignment: .center) {
            eventTextContent(for: event)

            Spacer()

            eventTrailingActions(for: event)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: event))
        .accessibilityValue(accessibilityValue(for: event))
        .accessibilityHint(accessibilityHint(for: event))
        .accessibilityAddTraits(event.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilitySortPriority(1)
        .accessibilityAction(named: completionActionName) {
            toggleCompletion(for: event)
        }
        .accessibilityAction(named: "Edit notes") {
            presentNotes(for: event)
        }
        .accessibilityAction(named: "Edit category") {
            presentCategory(for: event)
        }
        .accessibilityAction(named: "Delete event") {
            eventPendingDeletion = event
        }
        .simultaneousGesture(TapGesture())
        .onLongPressGesture {
            presentNotes(for: event)
        }
        .onTapGesture(count: 2) {
            presentCategory(for: event)
        }
        .gesture(eventSwipeGesture(for: event))
    }

    @ViewBuilder
    private func eventTextContent(for event: Event) -> some View {
        VStack(spacing: 1) {
            Text(eventTitle(for: event))
                .font(.body)
                .foregroundStyle(Color.textPrimary)
                .strikethrough(event.isCompleted, color: Color.textPrimary)
                .opacity(event.isCompleted ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.22), value: event.isCompleted)

            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(event.isCompleted ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.22), value: event.isCompleted)
            }

            if !event.category.isEmpty {
                Text(event.category)
                    .font(.caption2)
                    .foregroundStyle(Color.textPrimary.opacity(0.7))
                    .opacity(event.isCompleted ? 0.55 : 1.0)
                    .animation(.easeInOut(duration: 0.22), value: event.isCompleted)
                    .padding(.top, -2)
            }
        }
    }

    @ViewBuilder
    private func eventTrailingActions(for event: Event) -> some View {
        HStack(spacing: 12) {
            if !event.notes.isEmpty {
                NotesIndicator(
                    size: 4,
                    spacing: 4,
                    tint: Color.textPrimary.opacity(0.6)
                )
                .accessibilityHidden(true)
            }

            Button {
                eventPendingDeletion = event
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.textPrimary.opacity(0.08))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(event.title)")
            .accessibilityValue(event.isCompleted ? "Completed" : "Not completed")
            .accessibilityHint("Removes this event")
        }
    }

    private func eventSwipeGesture(for event: Event) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                guard abs(horizontalDistance) > 60, verticalDistance < 40 else { return }
                guard swipedEventID != event.persistentModelID else { return }

                if horizontalDistance > 0, !event.isCompleted {
                    swipedEventID = event.persistentModelID
                    withAnimation(.easeInOut(duration: 0.22)) {
                        event.isCompleted = true
                    }
                } else if horizontalDistance < 0, event.isCompleted {
                    swipedEventID = event.persistentModelID
                    withAnimation(.easeInOut(duration: 0.22)) {
                        event.isCompleted = false
                    }
                } else {
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if swipedEventID == event.persistentModelID {
                        swipedEventID = nil
                    }
                }
            }
    }

    private func toggleCompletion(for event: Event) {
        withAnimation(.easeInOut(duration: 0.22)) {
            event.isCompleted.toggle()
        }
    }

    private func presentNotes(for event: Event) {
        selectedEvent = event
        noteDraft = event.notes
        showNotesSheet = true
    }

    private func presentCategory(for event: Event) {
        selectedEvent = event
        categoryDraft = event.category
        showCategorySheet = true
    }

    private func eventTitle(for event: Event) -> String {
        if let time = event.time {
            let formattedTime = time.formatted(.dateTime.hour().minute())
            return "\(event.title) — \(formattedTime)"
        }

        if let reminderDate = event.reminderDate {
            let formattedReminder = reminderDate.formatted(.dateTime.hour().minute())
            return "\(event.title) — \(formattedReminder)"
        }

        return event.title
    }

    private func accessibilityLabel(for event: Event) -> String {
        var parts: [String] = [event.title]

        if let time = event.time {
            parts.append("at \(time.formatted(date: .omitted, time: .shortened))")
        } else if let reminderDate = event.reminderDate {
            parts.append("reminder at \(reminderDate.formatted(date: .omitted, time: .shortened))")
        }

        if !event.category.isEmpty {
            parts.append("category \(event.category)")
        }

        if !event.notes.isEmpty {
            parts.append("notes available")
        }

        parts.append(event.isCompleted ? "completed" : "not completed")

        return parts.joined(separator: ", ")
    }

    private func accessibilityValue(for event: Event) -> String {
        var details: [String] = []

        if !event.notes.isEmpty {
            details.append("Notes available")
        }

        if !event.category.isEmpty {
            details.append("Category \(event.category)")
        }

        details.append(event.isCompleted ? "Completed" : "Not completed")

        return details.joined(separator: ", ")
    }

    private func accessibilityHint(for event: Event) -> String {
        let completionAction = event.isCompleted ? "Swipe left or use actions to mark as not completed" : "Swipe right or use actions to mark as completed"
        return "\(completionAction). Long press to edit notes. Double tap to edit category. Additional actions available."
    }

    private func deleteEvent(_ event: Event) {
        if let reminderDate = event.reminderDate, reminderDate > Date() {
            let identifier = event.eventID.uuidString
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        modelContext.delete(event)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Event.self, inMemory: true)
}
