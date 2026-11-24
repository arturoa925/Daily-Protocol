import Foundation
import Testing
@testable import Launch_Control

struct LastActionStoreTests {

    // A throwaway defaults suite per test so nothing leaks into the app's real App Group.
    private func makeStore() -> LastActionStore {
        let suite = "LastActionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return LastActionStore(defaults: defaults)
    }

    @Test func takeReturnsNilWhenNothingWasRecorded() {
        #expect(makeStore().take() == nil)
    }

    @Test func takeReturnsTheRecordedActionOnce() {
        let store = makeStore()
        let id = UUID()
        store.record(.added(id))
        #expect(store.take() == .added(id))
        #expect(store.take() == nil)
    }

    @Test func newerActionReplacesOlderOne() {
        let store = makeStore()
        let first = UUID(), second = UUID()
        store.record(.added(first))
        store.record(.completed(second))
        #expect(store.take() == .completed(second))
    }

    @Test func staleActionsExpireAndAreCleared() {
        let store = makeStore()
        let recorded = Date()
        store.record(.added(UUID()), at: recorded)
        let later = recorded.addingTimeInterval(LastActionStore.maxAge + 1)
        #expect(store.take(now: later) == nil)
        #expect(store.take(now: recorded) == nil) // expired take still cleared it
    }

    @Test func actionJustInsideTheWindowStillCounts() {
        let store = makeStore()
        let recorded = Date()
        let id = UUID()
        store.record(.completed(id), at: recorded)
        #expect(store.take(now: recorded.addingTimeInterval(LastActionStore.maxAge)) == .completed(id))
    }

    @Test func snapshotRoundTripsEveryFieldIncludingItsID() {
        let original = Event(title: "Dentist", date: Date(timeIntervalSince1970: 1_800_000_000),
                             time: Date(timeIntervalSince1970: 1_800_003_600), notes: "bring card",
                             category: "Health", isCompleted: true, hasReminder: true,
                             reminderDate: Date(timeIntervalSince1970: 1_799_999_000))
        let restored = EventSnapshot(original).makeEvent()
        #expect(restored.eventID == original.eventID)
        #expect(restored.title == original.title)
        #expect(restored.date == original.date)
        #expect(restored.time == original.time)
        #expect(restored.notes == original.notes)
        #expect(restored.category == original.category)
        #expect(restored.isCompleted == original.isCompleted)
        #expect(restored.hasReminder == original.hasReminder)
        #expect(restored.reminderDate == original.reminderDate)
    }

    @Test func removedActionSurvivesEncodingWithItsSnapshot() {
        let store = makeStore()
        let snapshot = EventSnapshot(Event(title: "Gym", date: Date(), category: "Health"))
        store.record(.removed(snapshot))
        #expect(store.take() == .removed(snapshot))
    }
}
