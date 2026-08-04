//
//  ProtocolView.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/17/26.
//

import SwiftUI
import SwiftData
import UserNotifications


struct ProtocolView: View {
    @Query(sort: [
        SortDescriptor(\Event.date),
        SortDescriptor(\Event.createdAt)
    ]) private var events: [Event]
    @State private var showAddEventSheet = false
    @Environment(\.modelContext) private var modelContext
    @State private var eventTitle = ""
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var notificationErrorMessage: String?
    @State private var showNotesSheet = false
    @State private var selectedEvent: Event?
    @State private var noteDraft = ""
    @State private var showCategorySheet = false
    @State private var categoryDraft = ""
    @State private var eventPendingDeletion: Event?
    @State private var showSettings = false

    private let categories = ["Work", "Health", "Education", "Personal", "Social"]
    @State private var swipedEventID: PersistentIdentifier?

    // events are being filtered to today's here using new 'events' var
    private var todaysEvents: [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }

    private var completedTodaysEventsCount: Int {
        todaysEvents.filter { $0.isCompleted }.count
    }

    private var eventsForTodayAccessibilityValue: String {
        "\(todaysEvents.count) total events. \(completedTodaysEventsCount) completed."
    }

    private var formattedToday: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(events: events)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBackground
                    .ignoresSafeArea()

                protocolContent

                addEventButton
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings, including appearance.")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var protocolContent: some View {
        VStack(alignment: .center) {
            Text("Today is \(formattedToday)")
                .font(.title2)
                .padding(.top, 16)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Today is \(formattedToday)")
                .accessibilitySortPriority(3)

            if currentStreak > 0 {
                streakBadge
                    .padding(.top, 6)
            }

            Text("What are we getting done today?")
                .padding(.top, 16)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHint("This screen shows your protocol items for today.")
                .accessibilitySortPriority(2)

            Text("Events for Today")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 96)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Events for today")
                .accessibilityValue(eventsForTodayAccessibilityValue)
                .accessibilitySortPriority(2)

            if todaysEvents.isEmpty {
                emptyStateView
            } else {
                todaysEventsList
            }

            Spacer()
        }
        .padding()
    }

    private var streakBadge: some View {
        Text("\u{1F525} \(currentStreak) day\(currentStreak == 1 ? "" : "s") streak")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.textPrimary.opacity(0.85))
            .accessibilityLabel("Current streak")
            .accessibilityValue("\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
    }

    private var emptyStateView: some View {
        Text("No events yet. Tap the plus button to add your first event.")
            .font(.body)
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.top, 12)
            .accessibilityLabel("No events for today. Use the add event button to create your first event.")
            .accessibilityHint("Double tap the add event button in the lower corner to create one.")
    }

    private var todaysEventsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(todaysEvents.enumerated()), id: \.element.persistentModelID) { index, event in
                ProtocolEventRowView(
                    event: event,
                    position: index + 1,
                    total: todaysEvents.count,
                    onEditNotes: {
                        selectedEvent = event
                        noteDraft = event.notes
                        showNotesSheet = true
                    },
                    onChooseCategory: {
                        selectedEvent = event
                        categoryDraft = event.category
                        showCategorySheet = true
                    },
                    onDelete: {
                        eventPendingDeletion = event
                    },
                    onToggleCompletion: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            event.isCompleted.toggle()
                        }
                    },
                    onSwipeCompletionChange: { completedEvent in
                        swipedEventID = completedEvent.persistentModelID
                        withAnimation(.easeInOut(duration: 0.22)) {
                            completedEvent.isCompleted.toggle()
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            if swipedEventID == completedEvent.persistentModelID {
                                swipedEventID = nil
                            }
                        }
                    },
                    isSwipeLocked: swipedEventID == event.persistentModelID,
                    titleText: eventTitle(for: event),
                    accessibilityText: accessibilitySummary(for: event, position: index + 1, total: todaysEvents.count)
                )
            }
        }
        .padding(.top, 8)
    }

    private var addEventButton: some View {
        FloatingAddButton(action: prepareForNewEvent)
            .buttonStyle(.plain)
            .accessibilityLabel("Add event")
            .accessibilityHint("Opens a sheet to create a new event for today.")
            .accessibilityAddTraits(.isButton)
            .accessibilitySortPriority(4)
            .padding(24)
            .sheet(isPresented: $showAddEventSheet) {
                addEventSheet
            }
            .sheet(isPresented: $showNotesSheet) {
                notesSheet
            }
            .sheet(isPresented: $showCategorySheet) {
                categorySheet
            }
            .deleteEventAlert(pendingDeletion: $eventPendingDeletion, onDelete: deleteEvent)
            .alert("Notification Issue", isPresented: notificationAlertBinding) {
                Button("OK", role: .cancel) {
                    notificationErrorMessage = nil
                }
            } message: {
                Text(notificationErrorMessage ?? "")
            }
    }

    private var addEventSheet: some View {
        AddEventSheet(
            title: $eventTitle,
            hasReminder: $hasReminder,
            reminderDate: $reminderDate,
            onCancel: { showAddEventSheet = false },
            onSave: saveNewEvent
        )
    }

    private var notesSheet: some View {
        AddNotesSheet(
            notes: $noteDraft,
            onCancel: cancelNotesEditing,
            onSave: saveNotes
        )
    }

    private var categorySheet: some View {
        AddCategorySheet(
            categories: categories,
            selection: $categoryDraft,
            onCancel: cancelCategoryEditing,
            onSave: saveCategory
        )
    }

    private var notificationAlertBinding: Binding<Bool> {
        Binding(
            get: { notificationErrorMessage != nil },
            set: { if !$0 { notificationErrorMessage = nil } }
        )
    }

    private func prepareForNewEvent() {
        eventTitle = ""
        hasReminder = false
        reminderDate = Date()
        showAddEventSheet = true
    }

    private func saveNewEvent() {
        let trimmedTitle = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminder = hasReminder ? reminderDate : nil

        let newEvent = Event(
            title: trimmedTitle,
            date: Date(),
            time: nil,
            notes: "",
            category: "",
            hasReminder: hasReminder,
            reminderDate: reminder
        )

        modelContext.insert(newEvent)

        if let reminder {
            NotificationScheduler.scheduleNotification(
                for: String(describing: newEvent.persistentModelID),
                title: trimmedTitle,
                reminderDate: reminder
            ) { error in
                if let error {
                    DispatchQueue.main.async {
                        notificationErrorMessage = error.localizedDescription
                    }
                }
            }
        }

        showAddEventSheet = false
    }

    private func cancelNotesEditing() {
        showNotesSheet = false
        selectedEvent = nil
        noteDraft = ""
    }

    private func saveNotes() {
        selectedEvent?.notes = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        showNotesSheet = false
        selectedEvent = nil
        noteDraft = ""
    }

    private func cancelCategoryEditing() {
        showCategorySheet = false
        selectedEvent = nil
        categoryDraft = ""
    }

    private func saveCategory() {
        selectedEvent?.category = categoryDraft
        showCategorySheet = false
        selectedEvent = nil
        categoryDraft = ""
    }

    private func accessibilitySummary(for event: Event, position: Int, total: Int) -> String {
        var parts: [String] = ["Event \(position) of \(total)", event.title]

        if let time = event.time {
            parts.append("Time \(time.formatted(.dateTime.hour().minute()))")
        } else if let reminderDate = event.reminderDate {
            parts.append("Reminder at \(reminderDate.formatted(.dateTime.hour().minute()))")
        }

        if !event.notes.isEmpty {
            parts.append("Has notes")
        } else {
            parts.append("No notes")
        }

        if !event.category.isEmpty {
            parts.append("Category \(event.category)")
        } else {
            parts.append("No category selected")
        }

        parts.append(event.isCompleted ? "Completed" : "Not completed")

        return parts.joined(separator: ", ")
    }

    private func deleteEvent(_ event: Event) {
        if let reminderDate = event.reminderDate, reminderDate > Date() {
            let identifier = String(describing: event.persistentModelID)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }

        modelContext.delete(event)
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
}

private struct ProtocolEventRowView: View {
    let event: Event
    let position: Int
    let total: Int
    let onEditNotes: () -> Void
    let onChooseCategory: () -> Void
    let onDelete: () -> Void
    let onToggleCompletion: () -> Void
    let onSwipeCompletionChange: (Event) -> Void
    let isSwipeLocked: Bool
    let titleText: String
    let accessibilityText: String

    var body: some View {
        HStack(alignment: .center) {
            content
                .accessibilityHidden(true)

            Spacer()

            trailingControls
                .accessibilityElement(children: .contain)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Actions available: mark complete or incomplete, edit notes, and choose category. The delete button is announced separately.")
        .accessibilitySortPriority(1)
        .simultaneousGesture(TapGesture())
        .onLongPressGesture {
            onEditNotes()
        }
        .onTapGesture(count: 2) {
            onChooseCategory()
        }
        .gesture(swipeGesture)
        .accessibilityAction(named: event.isCompleted ? "Mark incomplete" : "Mark complete") {
            onToggleCompletion()
        }
        .accessibilityAction(named: "Edit notes") {
            onEditNotes()
        }
        .accessibilityAction(named: "Choose category") {
            onChooseCategory()
        }
        .accessibilityAction(named: "Delete event") {
            onDelete()
        }
    }

    private var content: some View {
        VStack(spacing: 2) {
            Text(titleText)
                .font(.body)
                .foregroundColor(Color.textPrimary)
                .strikethrough(event.isCompleted, color: Color.textPrimary)
                .opacity(event.isCompleted ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.22), value: event.isCompleted)


            if !event.category.isEmpty {
                Text(event.category)
                    .font(.caption2)
                    .foregroundStyle(Color.textPrimary.opacity(0.7))
                    .opacity(event.isCompleted ? 0.55 : 1.0)
                    .animation(.easeInOut(duration: 0.22), value: event.isCompleted)
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 12) {
            if !event.notes.isEmpty {
                NotesIndicator(
                    size: 4,
                    spacing: 4,
                    tint: Color.textPrimary.opacity(0.6)
                )
                .accessibilityHidden(true)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.textPrimary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(event.title)")
            .accessibilityHint("Removes this event from today.")
            .accessibilitySortPriority(1)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                guard abs(horizontalDistance) > 60, verticalDistance < 40 else { return }
                guard !isSwipeLocked else { return }

                if horizontalDistance > 0, !event.isCompleted {
                    onSwipeCompletionChange(event)
                } else if horizontalDistance < 0, event.isCompleted {
                    onSwipeCompletionChange(event)
                }
            }
    }
}

#Preview {
    ProtocolView()
        .modelContainer(for: Event.self, inMemory: true)
}
