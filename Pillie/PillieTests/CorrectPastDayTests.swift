//
//  CorrectPastDayTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

@MainActor
final class CorrectPastDayTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testCorrectPastDueDayToTakenWritesNilTakenAtAndCountsCheckIn() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-20")
        let yesterday = InMemoryStoreFactory.fixedDate("2026-05-25")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store
        let before = store.monthAdherence(for: yesterday)

        XCTAssertTrue(store.correctPastDay(on: yesterday, to: .taken))

        let snapshot = try XCTUnwrap(store.scheduleSnapshot(for: yesterday))
        XCTAssertEqual(snapshot.status, .taken)
        XCTAssertTrue(snapshot.countsTowardAdherence)

        let record = try XCTUnwrap(fixture.pack.days.first {
            Calendar.current.isDate($0.date, inSameDayAs: yesterday)
        })
        XCTAssertNil(record.takenAt)

        let after = store.monthAdherence(for: yesterday)
        XCTAssertEqual(after.completed, before.completed + 1)

        let cycleIndex = fixture.pack.cycleDayIndex(on: yesterday)
        XCTAssertEqual(
            store.cycleSnapshots(for: [cycleIndex], in: fixture.pack)[cycleIndex]?.status,
            .taken
        )
        XCTAssertGreaterThan(store.dayRecordsRevision, 0)
    }

    func testCorrectTakenDayToUnloggedRestoresMissAndDropsStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-24")
        let first = InMemoryStoreFactory.fixedDate("2026-05-24")
        let second = InMemoryStoreFactory.fixedDate("2026-05-25")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        store.markActionAsTaken(on: first)
        store.markActionAsTaken(on: second)
        XCTAssertEqual(store.currentStreak, 2)

        XCTAssertTrue(store.correctPastDay(on: second, to: .unlogged))

        XCTAssertEqual(store.scheduleSnapshot(for: second)?.status, .missed)
        // A miss must stop the walk. `default: break` inside a switch would
        // not leave the loop and would keep counting earlier taken days.
        XCTAssertEqual(store.currentStreak, 0)
    }

    func testCorrectPastDueDayToBreakExcludesAdherenceAndPreservesStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-24")
        let first = InMemoryStoreFactory.fixedDate("2026-05-24")
        let second = InMemoryStoreFactory.fixedDate("2026-05-25")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        store.markActionAsTaken(on: first)
        store.markActionAsTaken(on: second)
        XCTAssertEqual(store.currentStreak, 2)

        let before = store.monthAdherence(for: second)
        XCTAssertTrue(store.correctPastDay(on: second, to: .breakDay))

        let snapshot = try XCTUnwrap(store.scheduleSnapshot(for: second))
        XCTAssertEqual(snapshot.status, .breakDay)
        XCTAssertFalse(snapshot.countsTowardAdherence)
        XCTAssertEqual(store.currentStreak, 1)

        let after = store.monthAdherence(for: second)
        XCTAssertEqual(after.completed, before.completed - 1)
        XCTAssertEqual(after.due, before.due - 1)
    }

    func testCorrectPastDayRejectsToday() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: today)
        XCTAssertFalse(fixture.store.correctPastDay(on: today, to: .taken))
        XCTAssertEqual(fixture.store.dayRecordsRevision, 0)
    }

    func testCorrectPastDayRejectsDisallowedOutcomeWithoutSideEffects() throws {
        // Yesterday is a scheduled break with no record: not editable at all.
        let today = InMemoryStoreFactory.fixedDate("2026-06-16")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-25")
        let breakDay = InMemoryStoreFactory.fixedDate("2026-06-15")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store
        XCTAssertEqual(store.scheduleSnapshot(for: breakDay)?.dueAction?.type, .pillBreak)

        XCTAssertFalse(store.correctPastDay(on: breakDay, to: .taken))
        XCTAssertEqual(store.dayRecordsRevision, 0)
    }

    func testBackdatedRingInsertPinsInsertionAnchorLikeLiveCheckIn() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-24")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, method: .ring, startDate: startDate)
        let store = fixture.store
        XCTAssertNil(fixture.pack.ringInsertionDate)
        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.dueAction?.type, .ringInsert)

        XCTAssertTrue(store.correctPastDay(on: startDate, to: .taken))

        XCTAssertEqual(fixture.pack.ringInsertionDate, fixture.pack.startDate)
    }
}
