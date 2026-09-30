//
//  StartDayLiveDayTests.swift
//  PillieTests
//

#if DEBUG
import Foundation
import Testing

@testable import Pillie

@MainActor
struct StartDayLiveDayTests {
    private static var retained: [Any] = []

    private let eveningReminderHour = 20
    private let startDay = "2026-09-28"

    private func at(_ isoDate: String, hour: Int, minute: Int = 0) -> Date {
        InMemoryStoreFactory.localDate(isoDate, hour: hour, minute: minute)
    }

    /// A routine the way onboarding starts it: "Not yet" on day 1, evening reminder.
    private func notYetStore(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset = .twentyOneSeven,
        now: Date
    ) throws -> PillStore {
        let fixture = try InMemoryStoreFactory.makeStore(now: now, method: method, regimen: regimen)
        Self.retained.append(fixture)
        let store = fixture.store
        store.reminderHour = eveningReminderHour
        store.startNewProtocol(
            method: method,
            regimen: regimen,
            customRegimen: nil,
            cycleDay: 1,
            preserveHistory: false,
            anchorDay: TodayPillPick.Answer.anchorDay(
                for: .notYet,
                now: now,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute
            )
        )
        return store
    }

    @Test func `A ring started not yet is loggable before the reminder and starts the streak`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try notYetStore(method: .ring, now: at(startDay, hour: 12))

        #expect(store.todayDueAction?.type == .ringInsert)
        #expect(store.todayDueAction?.cycleDay == 1)
        #expect(store.currentDayIndex == 0)

        store.markTodayAsTaken()

        #expect(store.isTodayTaken)
        #expect(store.currentStreak == 1)
    }

    @Test func `A pill started not yet has day 1 due before the reminder`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try notYetStore(method: .pill, now: at(startDay, hour: 12))

        #expect(store.todayDueAction?.type == .pillActive)
        #expect(store.todayDueAction?.cycleDay == 1)
        #expect(store.isTodayHandled == false)

        store.markTodayAsTaken()

        #expect(store.currentStreak == 1)
    }

    @Test func `A patch started not yet has day 1 due before the reminder`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try notYetStore(method: .patch, now: at(startDay, hour: 12))

        #expect(store.todayDueAction?.type == .patchChange)
        #expect(store.todayDueAction?.cycleDay == 1)
    }

    @Test func `The first live day never precedes the routine's first day`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = at(startDay, hour: 12)
        let store = try notYetStore(method: .ring, now: now)

        #expect(store.today == Calendar.current.startOfDay(for: now))
    }

    @Test func `A routine started after the reminder keeps day 1 until the next reminder`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try notYetStore(method: .ring, now: at(startDay, hour: 21))
        let dayOne = Calendar.current.startOfDay(for: at(startDay, hour: 12))

        #expect(store.today == dayOne)
        #expect(store.todayDueAction?.type == .ringInsert)

        PillieClock.setFixedNowForTesting(at("2026-09-29", hour: 12))
        store.refreshDayContextIfNeeded()
        #expect(store.today == dayOne)
        #expect(store.currentDayIndex == 0)

        PillieClock.setFixedNowForTesting(at("2026-09-29", hour: 20, minute: 30))
        store.refreshDayContextIfNeeded()
        #expect(store.today != dayOne)
    }

    @Test func `Logging before the reminder carries through it without a second day 1`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try notYetStore(method: .ring, now: at(startDay, hour: 12))
        let dayOne = Calendar.current.startOfDay(for: at(startDay, hour: 12))
        store.markTodayAsTaken()

        PillieClock.setFixedNowForTesting(at(startDay, hour: 20, minute: 30))
        store.refreshDayContextIfNeeded()
        #expect(store.today == dayOne)
        #expect(store.currentDayIndex == 0)
        #expect(store.isTodayTaken)
        #expect(store.currentStreak == 1)

        PillieClock.setFixedNowForTesting(at("2026-09-29", hour: 12))
        store.refreshDayContextIfNeeded()
        #expect(store.today == dayOne)
        #expect(store.currentDayIndex == 0)
        #expect(store.currentStreak == 1)

        PillieClock.setFixedNowForTesting(at("2026-09-29", hour: 20, minute: 30))
        store.refreshDayContextIfNeeded()
        #expect(store.today != dayOne)
        #expect(store.currentDayIndex == 1)
    }
}
#endif
