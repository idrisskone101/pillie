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


    @Test func loggedWindowStaysYesterdayUntilTheReminder() {
        let wednesday = date("2026-09-23", hour: 0)
        let thursdaySix = date("2026-09-24", hour: 6)
        let live = LiveDoseDay.on(
            thursdaySix,
            reminderHour: 8,
            reminderMinute: 0,
            calendar: calendar
        )
        #expect(calendar.isDate(live, inSameDayAs: wednesday))
    }
}

@MainActor
struct DoseWindowStoreTests {
    @Test func eveningReminderStaysOpenAfterMidnight() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let reminderDay = InMemoryStoreFactory.localDate("2026-06-10", hour: 21)
        let afterMidnight = InMemoryStoreFactory.localDate("2026-06-11", hour: 1)
        let fixture = try InMemoryStoreFactory.makeStore(now: reminderDay, startDate: reminderDay)
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 0

        let doseDay = Calendar.current.startOfDay(for: reminderDay)
        #expect(fixture.store.statusForDate(doseDay) == .upcoming)

        PillieClock.setFixedNowForTesting(afterMidnight)
        fixture.store.refreshDayContextIfNeeded()

        #expect(fixture.store.statusForDate(doseDay) == .upcoming)
        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: doseDay))
    }

    @Test func eveningReminderClosesAtNextReminder() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let reminderDay = InMemoryStoreFactory.localDate("2026-06-10", hour: 21)
        let nextReminder = InMemoryStoreFactory.localDate("2026-06-11", hour: 21)
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

        let reminderDay = InMemoryStoreFactory.localDate("2026-06-10", hour: 21)
        let afterMidnight = InMemoryStoreFactory.localDate("2026-06-11", hour: 1)
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

    @Test func onlyTheReminderMovesTheLiveDay() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let wednesdayEvening = InMemoryStoreFactory.localDate("2026-09-23", hour: 20)
        let thursdayMidnight = InMemoryStoreFactory.localDate("2026-09-24", hour: 0, minute: 30)
        let thursdayEight = InMemoryStoreFactory.localDate("2026-09-24", hour: 8)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: wednesdayEvening,
            startDate: Calendar.current.startOfDay(for: wednesdayEvening)
        )
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let versionAtWednesday = fixture.store.protocolChangeVersion

        PillieClock.setFixedNowForTesting(thursdayMidnight)
        fixture.store.refreshDayContextIfNeeded()
        #expect(fixture.store.protocolChangeVersion == versionAtWednesday)

        PillieClock.setFixedNowForTesting(thursdayEight)
        fixture.store.refreshDayContextIfNeeded()
        #expect(fixture.store.protocolChangeVersion > versionAtWednesday)
        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: thursdayEight))
    }

    @Test func midnightMovesTheCivilDayButNotTheLiveDay() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let wednesdayEvening = InMemoryStoreFactory.localDate("2026-09-23", hour: 20)
        let thursdaySix = InMemoryStoreFactory.localDate("2026-09-24", hour: 6)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: wednesdayEvening,
            startDate: Calendar.current.startOfDay(for: wednesdayEvening)
        )
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        let versionAtWednesday = fixture.store.protocolChangeVersion

        PillieClock.setFixedNowForTesting(thursdaySix)
        fixture.store.refreshDayContextIfNeeded()

        #expect(fixture.store.civilDay == Calendar.current.startOfDay(for: thursdaySix))
        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: wednesdayEvening))
        #expect(fixture.store.protocolChangeVersion == versionAtWednesday)
    }

    @Test func takenWednesdayStaysWednesdayAtThursdaySixAM() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let wednesdayEvening = InMemoryStoreFactory.localDate("2026-09-23", hour: 20)
        let thursdaySix = InMemoryStoreFactory.localDate("2026-09-24", hour: 6)
        let wednesday = Calendar.current.startOfDay(for: wednesdayEvening)
        let thursday = Calendar.current.startOfDay(for: thursdaySix)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: wednesdayEvening,
            startDate: wednesday
        )
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        fixture.store.markTodayAsTaken()
        let streakAfterWednesday = fixture.store.currentStreak
        let wednesdayCycleDay = fixture.store.currentDayIndex

        PillieClock.setFixedNowForTesting(thursdaySix)
        fixture.store.refreshDayContextIfNeeded()

        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: wednesday))
        #expect(fixture.store.isTodayTaken)
        #expect(fixture.store.statusForDate(wednesday) == .taken)
        #expect(fixture.store.statusForDate(thursday) != .taken)
        #expect(fixture.store.currentStreak == streakAfterWednesday)
        #expect(fixture.store.currentDayIndex == wednesdayCycleDay)
        let nextOpen = try #require(fixture.store.alarmAction)
        #expect(Calendar.current.isDate(nextOpen.date, inSameDayAs: thursday))
        let loggedWednesday = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: wednesday, calendar: Calendar.current)
        )
        #expect(
            BlockingInterventionPolicy.decision(
                schedule: fixture.store.blockingScheduleMirror,
                handledStamp: loggedWednesday,
                now: thursdaySix,
                reminderHour: 8,
                reminderMinute: 0,
                calendar: Calendar.current
            ) == .clearShields
        )
    }

    @Test func openWednesdayAtThursdaySixAMStillLogsWednesday() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let wednesdayEvening = InMemoryStoreFactory.localDate("2026-09-23", hour: 20)
        let thursdaySix = InMemoryStoreFactory.localDate("2026-09-24", hour: 6)
        let wednesday = Calendar.current.startOfDay(for: wednesdayEvening)
        let thursday = Calendar.current.startOfDay(for: thursdaySix)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: wednesdayEvening,
            startDate: wednesday
        )
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0

        PillieClock.setFixedNowForTesting(thursdaySix)
        fixture.store.refreshDayContextIfNeeded()
        fixture.store.markTodayAsTaken()

        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: wednesday))
        #expect(fixture.store.statusForDate(wednesday) == .taken)
        #expect(fixture.store.statusForDate(thursday) != .taken)
    }

    @Test func thursdayReminderOpensThursdayAfterWednesdayWasTaken() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }

        let wednesdayEvening = InMemoryStoreFactory.localDate("2026-09-23", hour: 20)
        let thursdayEight = InMemoryStoreFactory.localDate("2026-09-24", hour: 8)
        let wednesday = Calendar.current.startOfDay(for: wednesdayEvening)
        let thursday = Calendar.current.startOfDay(for: thursdayEight)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: wednesdayEvening,
            startDate: wednesday
        )
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0
        fixture.store.markTodayAsTaken()

        PillieClock.setFixedNowForTesting(thursdayEight)
        fixture.store.refreshDayContextIfNeeded()

        #expect(Calendar.current.isDate(fixture.store.today, inSameDayAs: thursday))
        #expect(!fixture.store.isTodayTaken)
        let takeThursday = try #require(fixture.store.alarmAction)
        #expect(Calendar.current.isDate(takeThursday.date, inSameDayAs: thursday))
        #expect(fixture.store.currentDayIndex == fixture.store.pack.cycleDayIndex(on: thursday))
    }
}
#endif
