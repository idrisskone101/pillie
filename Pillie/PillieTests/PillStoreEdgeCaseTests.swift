//
//  PillStoreEdgeCaseTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class PillStoreEdgeCaseTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testConsecutiveDueActionsBuildStreakOverMultipleDays() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-24")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-24"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-25"))
        XCTAssertEqual(store.currentStreak, 2)

        store.markActionAsTaken(on: today)
        XCTAssertEqual(store.currentStreak, 3)
    }

    func testScheduledBreakWeekPreservesStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-28")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            regimen: .twentyOneSeven,
            startDate: startDate
        )
        let store = fixture.store

        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-19"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-20"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-21"))

        XCTAssertEqual(store.scheduleSnapshot(for: today)?.status, .breakDay)
        XCTAssertEqual(store.currentStreak, 3)
    }

    func testCycleDayAdjustmentBackfillDoesNotInflateStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        let store = fixture.store

        store.updateCycleDay(21)

        let startDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -20, to: today))
        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.status, .taken)
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.streakResetDate, PillieClock.today)

        store.markActionAsTaken(on: today)

        XCTAssertEqual(store.currentStreak, 1)
    }

    func testMarkTodayAfterCycleDayAdjustmentRefreshesStreakObservers() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        let store = fixture.store

        store.updateCycleDay(21)
        let versionAfterCycleDayChange = store.protocolChangeVersion

        store.markTodayAsTaken()

        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertGreaterThan(store.protocolChangeVersion, versionAfterCycleDayChange)
    }

    func testMonthBoundarySeparatesPastAndToday() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-03-01")
        let startDate = InMemoryStoreFactory.fixedDate("2026-02-28")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.status, .missed)
        XCTAssertEqual(store.scheduleSnapshot(for: today)?.status, .upcoming)

        store.markActionAsTaken(on: startDate)
        let adherence = store.monthAdherence(for: startDate)
        XCTAssertEqual(adherence.completed, 1)
        XCTAssertEqual(adherence.due, 1)
        XCTAssertEqual(adherence.percentage, 100)
    }

    func testLeapDayProducesExpectedDueAction() throws {
        let leapDay = InMemoryStoreFactory.fixedDate("2024-02-29")
        let fixture = try InMemoryStoreFactory.makeStore(now: leapDay, startDate: leapDay)

        let snapshot = fixture.store.scheduleSnapshot(for: leapDay)
        XCTAssertEqual(snapshot?.dueAction?.type, .pillActive)
        XCTAssertEqual(snapshot?.dueAction?.cycleDay, 1)
        XCTAssertEqual(snapshot?.status, .upcoming)
    }

    func testCustomReminderCopySurvivesContraceptionMethodChangeAndTrackingReset() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, method: .pill, startDate: today)
        let store = fixture.store

        store.customDueReminderTitle = "My own title 💖"
        store.customDueReminderBody = "Just for me."

        // A method change is a Tracking Data Reset (resetAndStartFresh wipes the records
        // and switches method). Custom copy is a Personalization Setting, so it must remain.
        store.resetAndStartFresh(
            method: .ring,
            regimen: .twentyOneSeven,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 1
        )

        XCTAssertEqual(store.contraceptiveMethod, .ring)
        XCTAssertEqual(store.customDueReminderTitle, "My own title 💖")
        XCTAssertEqual(store.customDueReminderBody, "Just for me.")
    }

    func testCustomReminderCopyPersistsAcrossStoreReload() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: today)
        fixture.store.customDueReminderTitle = "Persisted title"
        fixture.store.customDueReminderBody = "Persisted body"

        // A fresh PillStore over the same context reloads settings from UserDefaults —
        // models the app relaunching (e.g. after Plus lapses and later resubscribes).
        let reloaded = PillStore(modelContext: fixture.context)
        XCTAssertEqual(reloaded.customDueReminderTitle, "Persisted title")
        XCTAssertEqual(reloaded.customDueReminderBody, "Persisted body")
    }

    func testCustomPillValuesClampUnsafePersistedInput() {
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).active, 21)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).breakDays, 7)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).active, 1)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).breakDays, 7)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).active, 365)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).breakDays, 0)
    }
}
