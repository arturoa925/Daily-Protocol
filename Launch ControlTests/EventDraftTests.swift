import Foundation
import Testing
@testable import Launch_Control

struct EventDraftTests {

    // Fixed reference: Tuesday, 2026-11-24 at noon, Gregorian, so day math is deterministic.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
    }

    // MARK: - EventDraft sanitising (guards against bad model output)

    @Test func draftTrimsTitleAndNotes() {
        let draft = EventDraft(title: "  Call mom \n", dayOffset: 0, notes: " bring flowers ")
        #expect(draft.title == "Call mom")
        #expect(draft.notes == "bring flowers")
    }

    @Test func draftClampsOutOfRangeOffsets() {
        #expect(EventDraft(title: "x", dayOffset: -5).dayOffset == 0)
        #expect(EventDraft(title: "x", dayOffset: 9_999).dayOffset == EventDraft.maxDayOffset)
    }

    @Test func draftKeepsOnlyKnownCategoriesCaseInsensitively() {
        #expect(EventDraft(title: "x", dayOffset: 0, category: "health").category == "Health")
        #expect(EventDraft(title: "x", dayOffset: 0, category: "None").category == "")
        #expect(EventDraft(title: "x", dayOffset: 0, category: "Errands").category == "")
    }

    @Test func resolvedDateAddsDayOffsetInCalendarDays() {
        let draft = EventDraft(title: "x", dayOffset: 7)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 12))!
        #expect(draft.resolvedDate(calendar: calendar, now: now) == expected)
    }

    @Test func spokenDayUsesTodayAndTomorrow() {
        #expect(EventDraft(title: "x", dayOffset: 0).spokenDay(calendar: calendar, now: now) == "today")
        #expect(EventDraft(title: "x", dayOffset: 1).spokenDay(calendar: calendar, now: now) == "tomorrow")
    }

    // MARK: - Offline fallback parser

    @Test func parserDefaultsToTodayWithNoDayWords() {
        let draft = EventDraftParser.parse("Buy milk", calendar: calendar, now: now)
        #expect(draft.title == "Buy milk")
        #expect(draft.dayOffset == 0)
    }

    @Test func parserUnderstandsTomorrowAndStripsTheFiller() {
        let draft = EventDraftParser.parse("Add gym session tomorrow", calendar: calendar, now: now)
        #expect(draft.dayOffset == 1)
        #expect(draft.title == "Gym session")
        #expect(draft.category == "Health")
    }

    @Test func parserUnderstandsDayAfterTomorrowBeforeTomorrow() {
        #expect(EventDraftParser.parse("Dentist day after tomorrow", calendar: calendar, now: now).dayOffset == 2)
    }

    @Test func parserUnderstandsInNDays() {
        let draft = EventDraftParser.parse("Submit report in 3 days", calendar: calendar, now: now)
        #expect(draft.dayOffset == 3)
        #expect(draft.category == "Work")
    }

    @Test func parserResolvesWeekdaysRelativeToToday() {
        // 2026-11-24 is a Tuesday: Friday is 3 days out, Monday is 6.
        #expect(EventDraftParser.parse("Study on Friday", calendar: calendar, now: now).dayOffset == 3)
        #expect(EventDraftParser.parse("Study next Monday", calendar: calendar, now: now).dayOffset == 6)
    }

    @Test func parserTreatsNextSameWeekdayAsAWeekAway() {
        #expect(EventDraftParser.parse("Team meeting next Tuesday", calendar: calendar, now: now).dayOffset == 7)
    }

    @Test func parserFallsBackToOriginalTextIfNothingRemains() {
        let draft = EventDraftParser.parse("tomorrow", calendar: calendar, now: now)
        #expect(draft.dayOffset == 1)
        #expect(!draft.title.isEmpty)
    }

    // MARK: - Time of day

    @Test func draftDropsInvalidHours() {
        #expect(EventDraft(title: "x", dayOffset: 0, hour: 25).hour == nil)
        #expect(EventDraft(title: "x", dayOffset: 0, hour: -1).hour == nil)
        #expect(EventDraft(title: "x", dayOffset: 0, hour: 9, minute: 99).minute == 59)
    }

    @Test func resolvedTimeLandsOnTheEventsDay() {
        let draft = EventDraft(title: "x", dayOffset: 1, hour: 15, minute: 30)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 15, minute: 30))!
        #expect(draft.resolvedTime(calendar: calendar, now: now) == expected)
        #expect(EventDraft(title: "x", dayOffset: 0).resolvedTime(calendar: calendar, now: now) == nil)
    }

    @Test func parserReadsPMTimes() {
        let draft = EventDraftParser.parse("Dentist tomorrow at 3pm", calendar: calendar, now: now)
        #expect(draft.hour == 15 && draft.minute == 0)
        #expect(draft.title == "Dentist")
        #expect(draft.dayOffset == 1)
    }

    @Test func parserReadsMinutesAndAM() {
        let draft = EventDraftParser.parse("Standup at 9:30 am", calendar: calendar, now: now)
        #expect(draft.hour == 9 && draft.minute == 30)
    }

    @Test func parserHandlesNoonAndMidnightEdges() {
        #expect(EventDraftParser.parse("Lunch at noon", calendar: calendar, now: now).hour == 12)
        #expect(EventDraftParser.parse("Call at 12am", calendar: calendar, now: now).hour == 0)
        #expect(EventDraftParser.parse("Call at 12pm", calendar: calendar, now: now).hour == 12)
    }

    @Test func parserIgnoresBareNumbersThatAreNotTimes() {
        let draft = EventDraftParser.parse("Do 3 sets of squats", calendar: calendar, now: now)
        #expect(draft.hour == nil)
    }
}
