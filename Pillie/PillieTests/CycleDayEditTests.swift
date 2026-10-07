//
//  CycleDayEditTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// Settings > Cycle day edits the day the editor shows, and only the adjusted cycle.
@MainActor
final class CycleDayEditTests: XCTestCase {
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
        method: ContraceptiveMethod = .pill,
        startDate: String? = nil,
        reminderHour: Int = 8
    ) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(iso, hour: hour),
            method: method,
            startDate: startDate.map(day)
        )
        fixture = made
        made.store.reminderHour = reminderHour
        return made.store
    }

    private func setNow(_ iso: String, hour: Int, store: PillStore) {
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate(iso, hour: hour))
        store.refreshDayContextIfNeeded()
    }

    private func log(_ store: PillStore, from first: String, through last: String, skipping skipped: Set<String> = []) {
        var date = day(first)
        while date <= day(last) {
            if !skipped.contains(Self.iso(date)) {
                store.markActionAsTaken(on: date)
            }
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
    }

    private static func iso(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Set up at 9:00 AM with an 8:00 PM reminder, "not yet" on day `cycleDay`: that
    /// day is the calendar day, ahead of the live day that still holds yesterday's.
    private func storeSetUpBeforeTheReminder(method: ContraceptiveMethod = .pill, cycleDay: Int) throws -> PillStore {
        let store = try makeStore(now: "2026-10-07", hour: 9, method: method, reminderHour: 20)
        store.resetAndStartFresh(
            method: method,
            regimen: .twentyOneSeven,
            customRegimen: nil,
            cycleDay: cycleDay,
            anchorDay: store.anchorDay(for: .notYet)
        )
        return store
    }

    func testSavingTheShownCycleDayKeepsThePill() throws {
        let store = try storeSetUpBeforeTheReminder(cycleDay: 5)
        XCTAssertEqual(store.currentDayIndex + 1, 5)

        store.updateCycleDay(store.currentDayIndex + 1)

        XCTAssertEqual(store.currentDayIndex + 1, 5)
        XCTAssertFalse(store.isTodayTaken)
    }

    func testChangingTheCycleDayBeforeTheFirstReminderLandsOnTheShownDay() throws {
        let store = try storeSetUpBeforeTheReminder(cycleDay: 5)

        store.updateCycleDay(7)

        XCTAssertEqual(store.currentDayIndex + 1, 7)
        XCTAssertFalse(store.isTodayTaken)
        XCTAssertEqual(store.statusForDate(day("2026-10-06")), .taken)

        setNow("2026-10-07", hour: 21, store: store)

        XCTAssertEqual(store.currentDayIndex + 1, 7)
        XCTAssertEqual(store.statusForDate(day("2026-10-06")), .taken)
    }

    func testChangingThePatchDayBeforeTheFirstReminderKeepsTonightsChange() throws {
        let store = try storeSetUpBeforeTheReminder(method: .patch, cycleDay: 8)

        store.updateCycleDay(15)

        XCTAssertEqual(store.currentDayIndex + 1, 15)
        XCTAssertEqual(store.todayDueAction?.type, .patchChange)
    }

    func testSavingTheSameCycleDayKeepsTheStreak() throws {
        let store = try makeStore(now: "2026-10-01", hour: 12, startDate: "2026-09-24")
        log(store, from: "2026-09-24", through: "2026-09-30")
        XCTAssertEqual(store.currentStreak, 7)

        store.updateCycleDay(store.currentDayIndex + 1)

        XCTAssertEqual(store.currentStreak, 7)
    }

    /// 21/7 pack from 10 Sep with every pill logged; it ended 7 Oct and Start new was never tapped.
    func testSavingADayOnAFinishedPackKeepsItsHistory() throws {
        let store = try makeStore(now: "2026-10-09", hour: 12, startDate: "2026-09-10")
        log(store, from: "2026-09-10", through: "2026-09-30")
        XCTAssertTrue(store.isRefillDue)

        store.updateCycleDay(2)

        XCTAssertEqual(store.currentDayIndex + 1, 2)
        XCTAssertFalse(store.isRefillDue)
        XCTAssertEqual(store.statusForDate(day("2026-09-15")), .taken)
        XCTAssertEqual(store.monthAdherence(for: day("2026-09-15")).due, 21)
    }

    /// Pack 1 from 13 Aug left pill 8 (20 Aug) unlogged; pack 2 started on time on 10 Sep.
    func testChangingTheCycleDayKeepsEarlierPacksHistory() throws {
        let store = try makeStore(now: "2026-09-10", hour: 12, startDate: "2026-08-13")
        log(store, from: "2026-08-13", through: "2026-09-02", skipping: ["2026-08-20"])
        store.startNewPack()
        setNow("2026-09-20", hour: 12, store: store)
        XCTAssertEqual(store.statusForDate(day("2026-08-20")), .missed)
        XCTAssertEqual(store.statusForDate(day("2026-09-06")), .breakDay)

        store.updateCycleDay(store.currentDayIndex + 2)

        XCTAssertEqual(store.statusForDate(day("2026-08-20")), .missed)
        XCTAssertEqual(store.statusForDate(day("2026-09-06")), .breakDay)
    }
}
