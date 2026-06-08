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

    func testCustomPillValuesClampUnsafePersistedInput() {
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).active, 21)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).breakDays, 7)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).active, 1)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).breakDays, 28)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).active, 365)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).breakDays, 0)
    }
}
