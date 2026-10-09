//
//  TodayLogTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// A shake can outlast the live day it began on. It still logs the dose it showed.
@MainActor
final class TodayLogTests: XCTestCase {
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

    /// A 21 + 7 pack started on 1 May with the 8:00 AM reminder, a minute before that day's reminder.
    private func store(_ method: ContraceptiveMethod, beforeReminderOn iso: String) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(iso, hour: 7, minute: 59),
            method: method,
            startDate: day("2026-05-01")
        )
        fixture = made
        made.store.refreshDayContextIfNeeded()
        return made.store
    }

    private func passReminder(on iso: String, in store: PillStore) {
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate(iso, hour: 8).addingTimeInterval(4))
        store.refreshDayContextIfNeeded()
    }

    func testAPillShakeThatCrossesTheReminderLogsThePillItShowed() throws {
        let store = try store(.pill, beforeReminderOn: "2026-05-10")
        let shown = try XCTUnwrap(store.todayLog)
        XCTAssertEqual(shown, .due(shown.action))
        XCTAssertEqual(shown.action.date, day("2026-05-09"))

        passReminder(on: "2026-05-10", in: store)

        XCTAssertTrue(store.complete(shown))
        XCTAssertEqual(store.statusForDate(day("2026-05-09")), .taken)
        XCTAssertNotEqual(store.statusForDate(day("2026-05-10")), .taken)
        XCTAssertFalse(store.isTodayTaken)
    }

    func testAPatchChangeThatCrossesTheReminderLogsOnTimeNotLate() throws {
        let store = try store(.patch, beforeReminderOn: "2026-05-16")
        let shown = try XCTUnwrap(store.todayLog)
        XCTAssertEqual(shown, .due(shown.action))
        XCTAssertEqual(shown.action.date, day("2026-05-15"))

        passReminder(on: "2026-05-16", in: store)
        XCTAssertEqual(store.openCatchUp?.date, day("2026-05-15"))

        XCTAssertTrue(store.complete(shown))
        XCTAssertEqual(store.statusForDate(day("2026-05-15")), .taken)
        XCTAssertNil(store.caughtUpAt(on: day("2026-05-15")))
        XCTAssertNil(store.openCatchUp)
    }

    func testAnOpenCatchUpLogsLate() throws {
        let store = try store(.patch, beforeReminderOn: "2026-05-18")
        let shown = try XCTUnwrap(store.todayLog)
        XCTAssertEqual(shown, .catchUp(shown.action))

        XCTAssertTrue(store.complete(shown))
        XCTAssertEqual(store.statusForDate(day("2026-05-15")), .missed)
        XCTAssertEqual(store.caughtUpAt(on: day("2026-05-15")), InMemoryStoreFactory.localDate("2026-05-18", hour: 7, minute: 59))
    }

    func testACatchUpWhoseWindowClosesMidShakeLogsNothing() throws {
        let store = try store(.patch, beforeReminderOn: "2026-05-22")
        let shown = try XCTUnwrap(store.todayLog)
        XCTAssertEqual(shown, .catchUp(shown.action))
        XCTAssertEqual(shown.action.date, day("2026-05-15"))

        passReminder(on: "2026-05-22", in: store)
        XCTAssertEqual(store.todayDueAction?.type, .patchRemove)

        XCTAssertFalse(store.complete(shown))
        XCTAssertNotEqual(store.statusForDate(day("2026-05-22")), .taken)
        XCTAssertEqual(store.statusForDate(day("2026-05-15")), .missed)
        XCTAssertNil(store.caughtUpAt(on: day("2026-05-15")))
    }
}
