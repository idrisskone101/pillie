//
//  ReminderCheckInTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// The reminder's Check in action logs the dose it reminded about only while that
/// dose's window is open, the same rule Home's button follows.
@MainActor
final class ReminderCheckInTests: XCTestCase {
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

    private func makeStore(
        now iso: String,
        hour: Int,
        minute: Int = 0,
        method: ContraceptiveMethod = .pill,
        startDate: String,
        reminderHour: Int
    ) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(iso, hour: hour, minute: minute),
            method: method,
            startDate: day(startDate)
        )
        fixture = made
        made.store.reminderHour = reminderHour
        return made.store
    }

    private func checkIn(_ store: PillStore, onReminderFor iso: String) {
        KeptNotificationManager.make(hasBlockerSetup: { false })
            .completeReminder(store: store, dueDate: day(iso))
    }

    /// Patch from 1 May, 8 AM reminder: the day-8 change on 8 May was never logged.
    func testAStaleChangeReminderLogsTheChangeLate() throws {
        let store = try makeStore(now: "2026-05-09", hour: 10, method: .patch, startDate: "2026-05-01", reminderHour: 8)
        XCTAssertEqual(store.statusForDate(day("2026-05-08")), .missed)

        checkIn(store, onReminderFor: "2026-05-08")

        XCTAssertEqual(store.statusForDate(day("2026-05-08")), .missed)
        XCTAssertEqual(store.caughtUpAt(on: day("2026-05-08")), InMemoryStoreFactory.localDate("2026-05-09", hour: 10))
        XCTAssertNil(store.openCatchUp)
    }

    /// Pill from 1 Oct, 9 PM reminder: Monday's pill 5 was never logged and Tuesday's reminder has fired.
    func testAStalePillReminderDoesNotLogAClosedDay() throws {
        let store = try makeStore(now: "2026-10-06", hour: 21, minute: 10, startDate: "2026-10-01", reminderHour: 21)
        XCTAssertEqual(store.statusForDate(day("2026-10-05")), .missed)

        checkIn(store, onReminderFor: "2026-10-05")

        XCTAssertEqual(store.statusForDate(day("2026-10-05")), .missed)
        XCTAssertFalse(store.isTodayTaken)
    }

    /// Ring from 1 May, 8 AM reminder: day 29's reinsert window closed at 8 AM on day 30.
    func testAStaleReinsertReminderDoesNotStartACycle() throws {
        let store = try makeStore(now: "2026-05-30", hour: 9, method: .ring, startDate: "2026-05-01", reminderHour: 8)

        checkIn(store, onReminderFor: "2026-05-29")

        XCTAssertEqual(store.activePack?.packNumber, 1)
        XCTAssertTrue(store.isRefillDue)
    }

    func testTheLiveDaysReminderLogsItsDose() throws {
        let store = try makeStore(now: "2026-10-06", hour: 21, minute: 10, startDate: "2026-10-01", reminderHour: 21)

        checkIn(store, onReminderFor: "2026-10-06")

        XCTAssertTrue(store.isTodayTaken)
    }

    func testALateDoseStillOpenAfterMidnightLogs() throws {
        let store = try makeStore(now: "2026-10-06", hour: 0, minute: 30, startDate: "2026-10-01", reminderHour: 21)
        XCTAssertEqual(store.today, day("2026-10-05"))

        checkIn(store, onReminderFor: "2026-10-05")

        XCTAssertEqual(store.statusForDate(day("2026-10-05")), .taken)
    }
}
