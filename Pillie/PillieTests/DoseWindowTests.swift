#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct DoseWindowMathTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ iso: String, hour: Int, minute: Int = 0) -> Date {
        InMemoryStoreFactory.fixedDate(iso, hour: hour, minute: minute)
    }

    @Test func eveningDoseStaysOpenAfterMidnight() {
        let day = date("2026-06-10", hour: 0)
        let afterMidnight = date("2026-06-11", hour: 1)
        #expect(DoseWindow.isOpen(day: day, now: afterMidnight, hour: 21, minute: 0, calendar: calendar))
    }

    @Test func eveningDoseClosesAtNextReminder() {
        let day = date("2026-06-10", hour: 0)
        let nextReminder = date("2026-06-11", hour: 21)
        #expect(!DoseWindow.isOpen(day: day, now: nextReminder, hour: 21, minute: 0, calendar: calendar))
    }

    @Test func morningDoseIsClosedByNextNoon() {
        let day = date("2026-06-10", hour: 0)
        let nextNoon = date("2026-06-11", hour: 12)
        #expect(!DoseWindow.isOpen(day: day, now: nextNoon, hour: 8, minute: 0, calendar: calendar))
    }

    @Test func blockingIntervalEndWrapsPastMidnight() {
        #expect(DoseWindow.blockingIntervalEnd(hour: 21, minute: 0) == (20, 59))
        #expect(DoseWindow.blockingIntervalEnd(hour: 0, minute: 0) == (23, 59))
        #expect(DoseWindow.blockingIntervalEnd(hour: 8, minute: 30) == (8, 29))
    }

    @Test func contextTokenChangesAtReminderNotOnlyMidnight() {
        let before = date("2026-06-11", hour: 20, minute: 59)
        let after = date("2026-06-11", hour: 21)
        let beforeToken = DoseWindow.contextToken(now: before, hour: 21, minute: 0, calendar: calendar)
        let afterToken = DoseWindow.contextToken(now: after, hour: 21, minute: 0, calendar: calendar)
        #expect(beforeToken != afterToken)
    }
}

@MainActor
struct DoseWindowStoreTests {
    @Test func eveningReminderStaysOpenAfterMidnight() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let reminderDay = InMemoryStoreFactory.fixedDate("2026-06-10", hour: 21)
        let afterMidnight = InMemoryStoreFactory.fixedDate("2026-06-11", hour: 1)
        let fixture = try InMemoryStoreFactory.makeStore(now: reminderDay, startDate: reminderDay)
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 0

        let doseDay = Calendar.current.startOfDay(for: reminderDay)
        #expect(fixture.store.statusForDate(doseDay) == .upcoming)

        PillieClock.setFixedNowForTesting(afterMidnight)
        fixture.store.refreshDayContextIfNeeded()

        #expect(fixture.store.statusForDate(doseDay) == .upcoming)
        #expect(Calendar.current.isDate(fixture.store.activeDoseDate, inSameDayAs: doseDay))
    }

    @Test func eveningReminderClosesAtNextReminder() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let reminderDay = InMemoryStoreFactory.fixedDate("2026-06-10", hour: 21)
        let nextReminder = InMemoryStoreFactory.fixedDate("2026-06-11", hour: 21)
        let fixture = try InMemoryStoreFactory.makeStore(now: reminderDay, startDate: reminderDay)
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 0

        let doseDay = Calendar.current.startOfDay(for: reminderDay)
        PillieClock.setFixedNowForTesting(nextReminder)
        fixture.store.refreshDayContextIfNeeded()

        #expect(fixture.store.statusForDate(doseDay) == .missed)
    }

    @Test func afterMidnightTodayIsTheOpenDoseEverywhere() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let reminderDay = InMemoryStoreFactory.fixedDate("2026-06-10", hour: 21)
        let afterMidnight = InMemoryStoreFactory.fixedDate("2026-06-11", hour: 1)
        let fixture = try InMemoryStoreFactory.makeStore(now: reminderDay, startDate: reminderDay)
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 0
        let doseDay = Calendar.current.startOfDay(for: reminderDay)
        let streakBefore = fixture.store.currentStreak

        PillieClock.setFixedNowForTesting(afterMidnight)
        fixture.store.refreshDayContextIfNeeded()

        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: doseDay))
        #expect(fixture.store.currentDayIndex == fixture.store.pack.cycleDayIndex(on: doseDay))
        #expect(fixture.store.currentStreak == streakBefore)
        #expect(fixture.store.statusForDate(doseDay) == .upcoming)

        let versionBefore = fixture.store.protocolChangeVersion
        fixture.store.reminderHour = 0
        #expect(fixture.store.protocolChangeVersion > versionBefore)
        #expect(fixture.store.statusForDate(doseDay) == .missed)
    }
}
#endif
