//
//  MonthlyCompletionView.swift
//  Launch Control
//
//  Created by Arturo Ayala on 3/25/26.
//

import SwiftUI
import SwiftData

struct MonthlyCompletionView: View {
    let onShowWeek: () -> Void

    @Query(sort: [SortDescriptor(\Event.date, order: .forward)]) private var events: [Event]

    @State private var selectedWeek: MonthWeekSummary?
    @State private var isPressingWeekButton = false

    private let calendar = Calendar.current

    private var lastFourWeekStarts: [Date] {
        CompletionCalculator.lastFourWeekStarts(calendar: calendar)
    }

    private var weeklySummaries: [MonthWeekSummary] {
        lastFourWeekStarts.map { weekStart in
            let weekEvents = CompletionCalculator.events(events, inWeekStartingAt: weekStart, calendar: calendar)

            return MonthWeekSummary(
                date: weekStart,
                events: weekEvents,
                totalCount: weekEvents.count,
                completedCount: CompletionCalculator.completedCount(weekEvents)
            )
        }
    }

    private var selectedSummary: MonthWeekSummary {
        selectedWeek ?? weeklySummaries.last ?? .empty
    }

    private var totalEventsAcrossFourWeeks: Int {
        weeklySummaries.reduce(0) { $0 + $1.totalCount }
    }

    private var totalCompletedAcrossFourWeeks: Int {
        weeklySummaries.reduce(0) { $0 + $1.completedCount }
    }

    

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 36)

                    chartSection
                        .padding(.top, 40)

                    selectedWeekSection
                        .padding(.top, 24)

                   
                }
                .padding(.horizontal, 24)
            }
            Button {
                onShowWeek()
            } label: {
                Image(systemName: "chart.bar.xaxis")
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
                    .scaleEffect(isPressingWeekButton ? 0.94 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressingWeekButton)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0, maximumDistance: .infinity)
                    .onChanged { _ in
                        isPressingWeekButton = true
                    }
                    .onEnded { _ in
                        isPressingWeekButton = false
                    }
            )
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel("Show weekly progress")
            .accessibilityHint("Opens the weekly progress view.")
            .accessibilityAddTraits(.isButton)
        }
        .onAppear {
            if selectedWeek == nil {
                selectedWeek = weeklySummaries.last
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Progress Over 4 Weeks")
                .font(.title2)
                .foregroundStyle(Color.textPrimary)

            Text("Last 4 weeks")
                .font(.headline)
                .foregroundStyle(Color.textPrimary.opacity(0.9))

            Text("Total Events : \(totalEventsAcrossFourWeeks)")
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress over 4 weeks")
        .accessibilityValue("Last 4 weeks. Total events \(totalEventsAcrossFourWeeks). Completed events \(totalCompletedAcrossFourWeeks).")
        .accessibilityAddTraits(.isHeader)
    }

    private var chartSection: some View {
        VStack(spacing: 14) {
            MonthlyBarChartView(
                summaries: weeklySummaries,
                selectedDate: selectedSummary.date,
                onSelect: { summary in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedWeek = summary
                    }
                }
            )
            .frame(height: 280)
            .accessibilityLabel("Four week completion chart")
            .accessibilityHint("Swipe through the week bars to hear each week’s completion details.")
        }
    }

    private var selectedWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedWeekHeaderText)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(2)
                .accessibilityValue(weeklySummaryAccessibilityValue(for: selectedSummary))

            if selectedSummary.events.isEmpty {
                Text("No events created during this week.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("No events created during this week")
                    .accessibilityHint("Try selecting another week to review activity.")
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedSummary.events, id: \.persistentModelID) { event in
                        MonthlySelectedEventRow(event: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected week details")
        .accessibilityHint("Shows the currently selected week and its events.")
    }

    

    private var selectedWeekHeaderText: String {
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: selectedSummary.date) else {
            return "Week overview"
        }

        let startText = selectedSummary.date.formatted(.dateTime.month(.abbreviated).day())
        let endText = weekEnd.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) - \(endText) · \(selectedSummary.completedCount)/\(selectedSummary.totalCount) completed"
    }

    private func weeklySummaryAccessibilityValue(for summary: MonthWeekSummary) -> String {
        let startText = summary.date.formatted(.dateTime.month(.wide).day())
        let endText = calendar.date(byAdding: .day, value: 6, to: summary.date)?.formatted(.dateTime.month(.wide).day()) ?? "unknown end date"

        if summary.totalCount == 0 {
            return "Week of \(startText) through \(endText). No events created."
        }

        let completionPercentage = Int((Double(summary.completedCount) / Double(summary.totalCount)) * 100)
        return "Week of \(startText) through \(endText). \(summary.completedCount) of \(summary.totalCount) events completed. \(completionPercentage) percent complete."
    }
}

private struct MonthlyBarChartView: View {
    let summaries: [MonthlyCompletionView.MonthWeekSummary]
    let selectedDate: Date
    let onSelect: (MonthlyCompletionView.MonthWeekSummary) -> Void

    @State private var animatedBarIDs: Set<Date> = []
    @State private var dottedLineProgress: CGFloat = 0
    @AccessibilityFocusState private var focusedSummaryID: Date?

    private let maxBarHeight: CGFloat = 180
    private let barWidth: CGFloat = 72
    private let barSpacing: CGFloat = 22
    private let dotSize: CGFloat = 6
    private let dotVerticalOffset: CGFloat = 8
    private let accentLineColor = Color.chartAccentLine

    private var maxTotalCount: Int {
        max(summaries.map(\.totalCount).max() ?? 0, 1)
    }

    private var chartAccessibilityLabel: String {
        "Four week completion chart"
    }

    private var chartAccessibilityValue: String {
        if summaries.isEmpty {
            return "No weekly data available."
        }

        return summaries.map { summary in
            let start = weekStartLabel(for: summary.date)
            let end = weekEndLabel(for: summary.date)
            return "\(start) through \(end), \(summary.completedCount) of \(summary.totalCount) completed"
        }
        .joined(separator: ". ")
    }

    private var selectedSummaryAnnouncement: String {
        guard let selected = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else {
            return "No week selected."
        }

        let start = weekStartLabel(for: selected.date)
        let end = weekEndLabel(for: selected.date)
        return "Selected week \(start) through \(end). \(selected.completedCount) of \(selected.totalCount) completed."
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
                                VStack(spacing: 10) {
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
                                                    .delay(0.10 + (Double(index) * 0.05)),
                                                value: isAnimated
                                            )
                                    }

                                    VStack(spacing: 2) {
                                        Text(weekStartLabel(for: summary.date))
                                        Text(weekEndLabel(for: summary.date))
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textPrimary.opacity(0.68))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(width: barWidth)
                                }
                                .frame(width: barWidth)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(barAccessibilityLabel(for: summary))
                            .accessibilityValue(barAccessibilityValue(for: summary))
                            .accessibilityHint(isSelected ? "Selected week. The details appear below the chart." : "Double tap to view this week’s details below the chart.")
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
        .accessibilityHint("Each bar represents one week. Select a bar to update the details below.")
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

    private func height(for count: Int) -> CGFloat {
        if count <= 0 {
            return 22
        }

        return max((CGFloat(count) / CGFloat(maxTotalCount)) * maxBarHeight, 22)
    }

    private func completedHeight(for summary: MonthlyCompletionView.MonthWeekSummary) -> CGFloat {
        guard summary.totalCount > 0 else { return 0 }
        let ratio = CGFloat(summary.completedCount) / CGFloat(summary.totalCount)
        return max(height(for: summary.totalCount) * ratio, summary.completedCount > 0 ? 22 : 0)
    }

    private func dotYPosition(for summary: MonthlyCompletionView.MonthWeekSummary) -> CGFloat {
        let animatedCompletedHeight = animatedBarIDs.contains(summary.id) ? completedHeight(for: summary) : 0
        return maxBarHeight - animatedCompletedHeight - dotVerticalOffset - (dotSize / 2)
    }

    private func dottedLinePath(in size: CGSize) -> Path {
        var path = Path()
        guard !summaries.isEmpty else { return path }

        let stepX = barWidth + barSpacing
        let totalWidth = (CGFloat(summaries.count) * barWidth) + (CGFloat(max(summaries.count - 1, 0)) * barSpacing)
        let leadingInset = max((size.width - totalWidth) / 2, 0)

        let firstSummary = summaries[0]
        let startPoint = CGPoint(
            x: leadingInset,
            y: dotYPosition(for: firstSummary)
        )
        path.move(to: startPoint)

        for (index, summary) in summaries.enumerated() {
            let centerX = leadingInset + (barWidth / 2) + (CGFloat(index) * stepX)
            let y = dotYPosition(for: summary)
            path.addLine(to: CGPoint(x: centerX, y: y))
        }

        let lastSummary = summaries[summaries.count - 1]
        let endPoint = CGPoint(
            x: leadingInset + totalWidth,
            y: dotYPosition(for: lastSummary)
        )
        path.addLine(to: endPoint)

        return path
    }

    private func barAccessibilityLabel(for summary: MonthlyCompletionView.MonthWeekSummary) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"

        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: summary.date) else {
            return "Week summary"
        }

        return "Week of \(formatter.string(from: summary.date)) through \(formatter.string(from: weekEnd))"
    }

    private func barAccessibilityValue(for summary: MonthlyCompletionView.MonthWeekSummary) -> String {
        let isSelected = Calendar.current.isDate(summary.date, inSameDayAs: selectedDate)

        if summary.totalCount == 0 {
            return isSelected
                ? "Selected. No events created. 0 completed out of 0."
                : "No events created. 0 completed out of 0."
        }

        let completionPercentage = Int((Double(summary.completedCount) / Double(summary.totalCount)) * 100)
        let baseValue = "\(summary.completedCount) completed out of \(summary.totalCount). \(completionPercentage) percent complete."
        return isSelected ? "Selected. \(baseValue)" : baseValue
    }

    private func animateChartIfNeeded() {
        guard animatedBarIDs.isEmpty else { return }
        resetAndAnimateChart()
    }

    private func resetAndAnimateChart() {
        animatedBarIDs = []
        dottedLineProgress = 0

        for (index, summary) in summaries.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.06)) {
                withAnimation(.easeOut(duration: 0.45)) {
                    _ = animatedBarIDs.insert(summary.id)
                }
            }
        }

        let lineDelay = (Double(summaries.count) * 0.06) + 0.18
        DispatchQueue.main.asyncAfter(deadline: .now() + lineDelay) {
            withAnimation(.easeOut(duration: 0.55)) {
                dottedLineProgress = 1
            }
        }
    }

    private func weekStartLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func weekEndLabel(for date: Date) -> String {
        if let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: date) {
            return weekEnd.formatted(.dateTime.month(.abbreviated).day())
        }

        return ""
    }
}

private struct MonthlySelectedEventRow: View {
    let event: Event

    private var eventAccessibilityValue: String {
        let dateText = event.date.formatted(.dateTime.month(.wide).day())
        let statusText = event.isCompleted ? "Completed" : "Not completed"
        return "\(dateText). \(statusText)."
    }

    private var eventAccessibilityHint: String {
        event.isCompleted
            ? "Completed event in the selected week."
            : "Incomplete event in the selected week."
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
        .accessibilityValue(eventAccessibilityValue)
        .accessibilityHint(eventAccessibilityHint)
        .accessibilitySortPriority(1)
    }
}

extension MonthlyCompletionView {
    struct MonthWeekSummary: Identifiable, Equatable {
        let date: Date
        let events: [Event]
        let totalCount: Int
        let completedCount: Int

        var id: Date { date }

        static let empty = MonthWeekSummary(date: Date(), events: [], totalCount: 0, completedCount: 0)
    }
}

#Preview {
    MonthlyCompletionView(onShowWeek: {})
        .modelContainer(for: Event.self, inMemory: true)
}

