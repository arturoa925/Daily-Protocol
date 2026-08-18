

import SwiftUI
import SwiftData

struct WeeklyCompletionView: View {
    let onShowMonth: () -> Void

    @Query(sort: [SortDescriptor(\Event.date, order: .forward)]) private var events: [Event]

    @State private var selectedDay: WeekDaySummary?
    @State private var isPressingCalendarButton = false
    @Environment(\.isActiveScreen) private var isActiveScreen
    @AppStorage("actionButtonSide") private var actionButtonSideRaw: String = ActionButtonSide.trailing.rawValue

    private var actionButtonSide: ActionButtonSide {
        ActionButtonSide(rawValue: actionButtonSideRaw) ?? .trailing
    }

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        CompletionCalculator.weekDays(calendar: calendar)
    }

    private var weeklySummaries: [WeekDaySummary] {
        weekDays.map { day in
            let dayEvents = eventsForDay(day)
            let completedCount = CompletionCalculator.completedCount(dayEvents)

            return WeekDaySummary(
                date: day,
                events: dayEvents,
                totalCount: dayEvents.count,
                completedCount: completedCount
            )
        }
    }

    private var totalEventsThisWeek: Int {
        weeklySummaries.reduce(0) { $0 + $1.totalCount }
    }

    private var completedEventsThisWeek: Int {
        weeklySummaries.reduce(0) { $0 + $1.completedCount }
    }

    private var remainingEventsThisWeek: Int {
        max(totalEventsThisWeek - completedEventsThisWeek, 0)
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(events: events)
    }

    private var selectedSummary: WeekDaySummary {
        selectedDay
            ?? weeklySummaries.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) })
            ?? weeklySummaries.first
            ?? .empty
    }

    var body: some View {
        ZStack(alignment: actionButtonSide.alignment) {
            Color.appBackground
                .ignoresSafeArea()

            PageScrollView(page: 2) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 36)

                    chartSection
                        .padding(.top, 36)

                    selectedDaySection
                        .padding(.top, 20)

                    remainingEventsSection
                        .padding(.top, 60)
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, 24)
            }

            Button {
                onShowMonth()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 64, height: 64)
                    .background(
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.textPrimary.opacity(0.20),
                                            Color.textPrimary.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Circle()
                                .fill(Color.textPrimary.opacity(0.03))
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.textPrimary.opacity(0.35),
                                        Color.textPrimary.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.textPrimary.opacity(0.32),
                                        Color.textPrimary.opacity(0.02)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blur(radius: 6)
                            .mask(
                                Circle()
                                    .padding(4)
                            )
                    )
                    .shadow(color: Color.textPrimary.opacity(0.08), radius: 2, x: 0, y: -1)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                    .scaleEffect(isPressingCalendarButton ? 0.94 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressingCalendarButton)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open month view")
            .accessibilityHint("Shows the monthly calendar.")
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0, maximumDistance: .infinity)
                    .onChanged { _ in
                        isPressingCalendarButton = true
                    }
                    .onEnded { _ in
                        isPressingCalendarButton = false
                    }
            )
            .padding(actionButtonSide.edge, 20)
            .padding(.bottom, 20)
            .accessibilityAddTraits(.isButton)
            .accessibilitySortPriority(3)
        }
        .onAppear {
            if selectedDay == nil {
                selectedDay = weeklySummaries.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) })
            }
        }
        // Applied here as well as in ContentView: the floating button's gesture
        // modifiers host it outside the parent's accessibility scope.
        .accessibilityHidden(!isActiveScreen)
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Progress this Week")
                .font(.title2)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(weekRangeText)
                .font(.headline)
                .foregroundStyle(Color.textPrimary.opacity(0.9))
                .accessibilityLabel("\(weekRangeText)")

            Text("Total Events : \(totalEventsThisWeek)")
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary.opacity(0.82))
                .accessibilityLabel("Total events this week: \(totalEventsThisWeek)")

            if currentStreak > 0 {
                Text("\u{1F525} \(currentStreak) day\(currentStreak == 1 ? "" : "s") streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress this week")
        .accessibilityValue("\(weekRangeText). Total events \(totalEventsThisWeek). Completed events \(completedEventsThisWeek). Remaining events \(remainingEventsThisWeek). Current streak \(currentStreak) day\(currentStreak == 1 ? "" : "s").")
        .accessibilityAddTraits(.isHeader)
    }

    private var chartSection: some View {
        VStack(spacing: 12) {
            WeeklyBarChartView(
                summaries: weeklySummaries,
                selectedDate: selectedSummary.date,
                onSelect: { summary in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDay = summary
                    }
                }
            )
            .frame(height: 240)
            .accessibilityLabel("Weekly completion chart")
            .accessibilityHint("Tap through the day bars to hear each day’s completion details.")
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDayHeaderText)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(selectedDayAccessibilityLabel)
                .accessibilityValue(selectedDayAccessibilityValue)
                .accessibilitySortPriority(2)

            if selectedSummary.events.isEmpty {
                Text("No events created for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("No events created for the selected day.")
                    .accessibilityHint("Try selecting another day to review activity.")
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedSummary.events, id: \.persistentModelID) { event in
                        SelectedEventRow(event: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected day details")
        .accessibilityHint("Shows the currently selected day and its events.")
    }

    private var remainingEventsSection: some View {
        Text("Remaining Events : \(remainingEventsThisWeek)")
            .font(.title3)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Remaining events this week")
            .accessibilityValue("\(remainingEventsThisWeek)")
    }

    private var weekRangeText: String {
        guard let startDay = weekDays.first, let endDay = weekDays.last else {
            return "Week"
        }

        let startText = startDay.formatted(.dateTime.weekday(.abbreviated).day())
        let endText = endDay.formatted(.dateTime.weekday(.abbreviated).day())
        return "Week \(startText) - \(endText)"
    }

    private var selectedDayHeaderText: String {
        let dayText = selectedSummary.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(dayText) · \(selectedSummary.completedCount)/\(selectedSummary.totalCount) completed"
    }

    private var selectedDayAccessibilityLabel: String {
        let dayText = selectedSummary.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "Selected day: \(dayText). \(selectedSummary.completedCount) completed out of \(selectedSummary.totalCount) events."
    }

    private var selectedDayAccessibilityValue: String {
        let total = selectedSummary.totalCount
        let completed = selectedSummary.completedCount

        if total == 0 {
            return "No events created for this day."
        }

        let percentage = Int((Double(completed) / Double(total)) * 100)
        return "\(completed) of \(total) events completed. \(percentage) percent complete."
    }

    private func eventsForDay(_ day: Date) -> [Event] {
        CompletionCalculator.events(events, onDay: day, calendar: calendar)
    }
}

private struct WeeklyBarChartView: View {
    let summaries: [WeeklyCompletionView.WeekDaySummary]
    let selectedDate: Date
    let onSelect: (WeeklyCompletionView.WeekDaySummary) -> Void

    @State private var animatedBarIDs: Set<Date> = []
    @State private var dottedLineProgress: CGFloat = 0
    @AccessibilityFocusState private var focusedSummaryID: Date?

    private let maxBarHeight: CGFloat = 160
    private let maxBarWidth: CGFloat = 28
    private let barSpacing: CGFloat = 14
    private let dotSize: CGFloat = 6
    private let dotVerticalOffset: CGFloat = 8
    private let accentLineColor = Color.chartAccentLine

    private var chartAccessibilityLabel: String {
        "Weekly completion chart"
    }

    private var chartAccessibilityValue: String {
        if summaries.isEmpty {
            return "No daily data available."
        }

        return summaries.map { summary in
            let dayName = summary.date.formatted(.dateTime.weekday(.wide))
            return "\(dayName), \(summary.completedCount) of \(summary.totalCount) completed"
        }
        .joined(separator: ". ")
    }

    private var maxTotalCount: Int {
        max(summaries.map { $0.totalCount }.max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    dottedLinePath(in: CGSize(width: proxy.size.width, height: maxBarHeight))
                        .trim(from: 0, to: dottedLineProgress)
                        .stroke(
                            accentLineColor.opacity(0.9),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [3, 4])
                        )
                        .animation(.easeOut(duration: 0.55), value: dottedLineProgress)

                    let barWidth = barWidth(forAvailable: proxy.size.width)

                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                            let totalHeight = height(for: summary.totalCount)
                            let completedHeight = completedHeight(for: summary)
                            let isSelected = Calendar.current.isDate(summary.date, inSameDayAs: selectedDate)
                            let isAnimated = animatedBarIDs.contains(summary.id)
                            let animatedCompletedHeight = isAnimated ? completedHeight : 0

                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    onSelect(summary)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    CompletionBar(
                                        barWidth: barWidth,
                                        maxBarHeight: maxBarHeight,
                                        totalHeight: totalHeight,
                                        completedHeight: animatedCompletedHeight,
                                        isSelected: isSelected
                                    )
                                    .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
                                    .overlay(alignment: .bottom) {
                                        Circle()
                                            .fill(accentLineColor)
                                            .frame(width: dotSize, height: dotSize)
                                            .opacity(isAnimated ? 1 : 0)
                                            .scaleEffect(isAnimated ? 1 : 0.7)
                                            .offset(y: -(animatedCompletedHeight + dotVerticalOffset))
                                            .animation(
                                                .spring(response: 0.32, dampingFraction: 0.8)
                                                    .delay(0.10 + (Double(index) * 0.04)),
                                                value: isAnimated
                                            )
                                    }

                                    Text(summary.date.formatted(.dateTime.weekday(.narrow)))
                                        .font(.caption2)
                                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textPrimary.opacity(0.65))
                                }
                                .frame(width: barWidth)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(dayAccessibilityLabel(for: summary))
                            .accessibilityValue(dayAccessibilityValue(for: summary))
                            .accessibilityHint(isSelected ? "Selected day. The details appear below the chart." : "Tap to view this day’s details below the chart.")
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            .accessibilitySortPriority(isSelected ? 2 : 1)
                            .accessibilityFocused($focusedSummaryID, equals: summary.id)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: maxBarHeight)

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityHint("Each bar represents one day. Select a bar to update the details below.")
        .onAppear {
            animateChartIfNeeded()
            if focusedSummaryID == nil {
                focusedSummaryID = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })?.id
            }
        }
        .onChange(of: summaries.map(\.id)) { _, _ in
            resetAndAnimateChart()
            focusedSummaryID = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })?.id
        }
        .onChange(of: selectedDate) { _, newValue in
            focusedSummaryID = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: newValue) })?.id
        }
    }

    private func dayAccessibilityLabel(for summary: WeeklyCompletionView.WeekDaySummary) -> String {
        summary.date.formatted(.dateTime.weekday(.wide))
    }

    private func dayAccessibilityValue(for summary: WeeklyCompletionView.WeekDaySummary) -> String {
        let isSelected = Calendar.current.isDate(summary.date, inSameDayAs: selectedDate)

        if summary.totalCount == 0 {
            return isSelected
                ? "Selected. No events created. 0 completed out of 0."
                : "No events created. 0 completed out of 0."
        }

        let percentage = Int((Double(summary.completedCount) / Double(summary.totalCount)) * 100)
        let baseValue = "\(summary.completedCount) completed out of \(summary.totalCount). \(percentage) percent complete."
        return isSelected ? "Selected. \(baseValue)" : baseValue
    }

    /// Shrinks the bars when the container is too narrow to fit them at full width,
    /// so the chart stays inside its margins on smaller iPhones.
    private func barWidth(forAvailable width: CGFloat) -> CGFloat {
        let count = CGFloat(summaries.count)
        guard count > 0 else { return 0 }

        return min(maxBarWidth, max((width - barSpacing * (count - 1)) / count, 1))
    }

    private func height(for count: Int) -> CGFloat {
        guard count > 0 else { return 18 }
        return max((CGFloat(count) / CGFloat(maxTotalCount)) * maxBarHeight, 18)
    }

    private func completedHeight(for summary: WeeklyCompletionView.WeekDaySummary) -> CGFloat {
        let totalHeight = height(for: summary.totalCount)
        guard summary.totalCount > 0 else { return 0 }

        let ratio = CGFloat(summary.completedCount) / CGFloat(summary.totalCount)
        return max(totalHeight * ratio, summary.completedCount > 0 ? 6 : 0)
    }

    private func dotYPosition(for summary: WeeklyCompletionView.WeekDaySummary) -> CGFloat {
        let animatedCompletedHeight = animatedBarIDs.contains(summary.id) ? completedHeight(for: summary) : 0
        return maxBarHeight - animatedCompletedHeight - dotVerticalOffset - (dotSize / 2)
    }

    private func dottedLinePath(in size: CGSize) -> Path {
        var path = Path()
        guard !summaries.isEmpty else { return path }

        let barWidth = barWidth(forAvailable: size.width)
        let stepX = barWidth + barSpacing
        let totalWidth = (CGFloat(summaries.count) * barWidth) + (CGFloat(max(summaries.count - 1, 0)) * barSpacing)
        let leadingInset = max((size.width - totalWidth) / 2, 0)

        for (index, summary) in summaries.enumerated() {
            let x = leadingInset + (barWidth / 2) + (CGFloat(index) * stepX)
            let y = dotYPosition(for: summary)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func animateChartIfNeeded() {
        guard animatedBarIDs.isEmpty else { return }
        resetAndAnimateChart()
    }

    private func resetAndAnimateChart() {
        animatedBarIDs = []
        dottedLineProgress = 0

        for (index, summary) in summaries.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.05)) {
                withAnimation(.easeOut(duration: 0.42)) {
                    _ = animatedBarIDs.insert(summary.id)
                }
            }
        }

        let lineDelay = (Double(summaries.count) * 0.05) + 0.16
        DispatchQueue.main.asyncAfter(deadline: .now() + lineDelay) {
            withAnimation(.easeOut(duration: 0.55)) {
                dottedLineProgress = 1
            }
        }
    }
}

private struct SelectedEventRow: View {
    let event: Event

    private var accessibilitySummary: String {
        var parts: [String] = [event.title]

        parts.append("Date \(event.date.formatted(.dateTime.month(.wide).day()))")

        if let time = event.time {
            parts.append("Time \(time.formatted(.dateTime.hour().minute()))")
        } else if let reminderDate = event.reminderDate {
            parts.append("Reminder at \(reminderDate.formatted(.dateTime.hour().minute()))")
        }

        if !event.notes.isEmpty {
            parts.append("Has notes")
        }

        if !event.category.isEmpty {
            parts.append("Category \(event.category)")
        }

        parts.append(event.isCompleted ? "Completed" : "Not completed")

        return parts.joined(separator: ", ")
    }

    private var accessibilityHintText: String {
        event.isCompleted
            ? "Completed event in the selected day."
            : "Incomplete event in the selected day."
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(event.title) — \(event.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                    .strikethrough(event.isCompleted, color: Color.textPrimary)
                    .opacity(event.isCompleted ? 0.72 : 1.0)
                    .accessibilityHidden(true)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.title)
        .accessibilityValue(accessibilitySummary)
        .accessibilityHint(accessibilityHintText)
        .accessibilitySortPriority(1)
    }
}

extension WeeklyCompletionView {
    struct WeekDaySummary: Identifiable, Equatable {
        let date: Date
        let events: [Event]
        let totalCount: Int
        let completedCount: Int

        var id: Date { date }

        static let empty = WeekDaySummary(date: Date(), events: [], totalCount: 0, completedCount: 0)
    }
}

#Preview {
    WeeklyCompletionView(onShowMonth: {})
        .modelContainer(for: Event.self, inMemory: true)
}
