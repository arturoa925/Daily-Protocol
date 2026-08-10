

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
    @State private var editor = EventEditor()

    @State private var swipedEventID: PersistentIdentifier?
    @Environment(\.isActiveScreen) private var isActiveScreen
    @AppStorage("actionButtonSide") private var actionButtonSideRaw: String = ActionButtonSide.trailing.rawValue

    private var actionButtonSide: ActionButtonSide {
        ActionButtonSide(rawValue: actionButtonSideRaw) ?? .trailing
    }

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
        ZStack(alignment: actionButtonSide.alignment) {
            Color.appBackground
                .ignoresSafeArea()

            PageScrollView(page: 1) {
                // calendar with events
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
                // Default reminder time to selected day at 9 AM
                let calendar = Calendar.current
                let defaultReminderDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                editor.prepareForNewEvent(defaultReminderDate: defaultReminderDate)
            })
            .accessibilityLabel("Add event")
            .accessibilityValue(selectedDateAccessibilityLabel)
            .accessibilityHint("Opens the sheet to create a new event for the selected date")
            .accessibilitySortPriority(1)
            .padding(24)
            .eventEditingSheets(
                editor: editor,
                categories: EventEditor.defaultCategories,
                modelContext: modelContext,
                newEventDate: { Calendar.current.startOfDay(for: selectedDate) }
            )
        }
        // Applied here as well as in ContentView: the floating button's sheet and
        // gesture modifiers host it outside the parent's accessibility scope.
        .accessibilityHidden(!isActiveScreen)
    }

        // events container
    @ViewBuilder
    private func eventRow(for event: Event) -> some View {
        let completionActionName = event.isCompleted ? "Mark as not completed" : "Mark as completed"

        HStack(alignment: .center) {
            // event text
            eventTextContent(for: event)

            Spacer()
            // event modifiers
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
            editor.toggleCompletion(for: event)
        }
        .accessibilityAction(named: "Edit notes") {
            editor.presentNotes(for: event)
        }
        .accessibilityAction(named: "Edit category") {
            editor.presentCategory(for: event)
        }
        .accessibilityAction(named: "Delete event") {
            editor.eventPendingDeletion = event
        }
        .simultaneousGesture(TapGesture())
        .onLongPressGesture {
            editor.presentNotes(for: event)
        }
        .onTapGesture(count: 2) {
            editor.presentCategory(for: event)
        }
        .gesture(eventSwipeGesture(for: event))
    }

    @ViewBuilder
    private func eventTextContent(for event: Event) -> some View {
        VStack(spacing: 1) {
            Text(event.displayTitle)
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
                editor.eventPendingDeletion = event
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

    // swipe to mark as complete
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

}

#Preview {
    CalendarView()
        .modelContainer(for: Event.self, inMemory: true)
}
