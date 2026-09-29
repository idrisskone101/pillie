//
//  CatchUpStoreTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

@MainActor
final class CatchUpStoreTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?

    override func tearDown() {
        fixture = nil
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private func day(_ iso: String) -> Date {
        Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate(iso, hour: 12))
    }

    /// A 21 + 7 patch started on 1 May; noon is past the 8:00 AM reminder.
    private func makeStore(_ method: ContraceptiveMethod, today: String) throws -> InMemoryStoreFixture {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(today, hour: 12),
            method: method,
            startDate: day("2026-05-01")
        )
        fixture = made
        return made
    }

    private func patchStore(today: String) throws -> InMemoryStoreFixture {
        try makeStore(.patch, today: today)
    }

    func testMissedChangeIsLoggableLateAndStaysMissed() throws {
        let fixture = try patchStore(today: "2026-05-18")
        let store = fixture.store
        let changeDay = day("2026-05-15")

        let open = try XCTUnwrap(store.openCatchUp)
        XCTAssertEqual(open.type, .patchChange)
        XCTAssertEqual(open.cycleDay, 15)
        XCTAssertEqual(open.date, changeDay)
        XCTAssertNil(store.todayDueAction)

        store.logCatchUp()

        XCTAssertNil(store.openCatchUp)
        XCTAssertTrue(store.isCaughtUpToday)
        XCTAssertEqual(store.caughtUpAt(on: changeDay), InMemoryStoreFactory.localDate("2026-05-18", hour: 12))
        XCTAssertEqual(store.statusForDate(changeDay), .missed)
        XCTAssertEqual(fixture.pack.days.first { $0.date == changeDay }?.status, .missed)

        store.undoCatchUp()

        XCTAssertEqual(store.openCatchUp?.date, changeDay)
        XCTAssertFalse(store.isCaughtUpToday)
        XCTAssertNil(store.caughtUpAt(on: changeDay))
        XCTAssertEqual(store.statusForDate(changeDay), .missed)
    }

    func testHistoryCorrectionClearsTheLateLog() throws {
        let store = try patchStore(today: "2026-05-18").store
        let changeDay = day("2026-05-15")
        store.logCatchUp()

        XCTAssertTrue(store.correctPastDay(on: changeDay, to: .taken))

        XCTAssertNil(store.caughtUpAt(on: changeDay))
        XCTAssertEqual(store.statusForDate(changeDay), .taken)
        XCTAssertNil(store.openCatchUp)
    }

    func testTheNextTaskDayClosesTheWindow() throws {
        let store = try patchStore(today: "2026-05-22").store

        XCTAssertNil(store.openCatchUp)
        XCTAssertEqual(store.todayDueAction?.type, .patchRemove)
    }

    func testAFinishedRingCycleHasNoCatchUp() throws {
        let store = try makeStore(.ring, today: "2026-05-30").store

        XCTAssertTrue(store.isRefillDue)
        XCTAssertNil(store.catchUp)
    }

    func testPillsHaveNoCatchUp() throws {
        let store = try makeStore(.pill, today: "2026-05-10").store

        XCTAssertEqual(store.statusForDate(day("2026-05-09")), .missed)
        XCTAssertNil(store.catchUp)
    }
}
