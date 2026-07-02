//
//  CycleMathConsistencyTests.swift
//  PillieTests
//
//  Guards the cycle-math invariants that keep the due engine, calendar, cycle
//  strip, and refill banner in agreement:
//  - patch/ring due actions honor a mid-cycle anchor (method switches)
//  - refill detection fires when the cycle actually completes
//  - past days beyond a finished cycle are no-data, not phantom misses
//  - cycle-day edits keep today's check-in
//  - day rollover invalidates the today-relative snapshot cache
//

import XCTest
@testable import Pillie

@MainActor
final class CycleMathConsistencyTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: date)!
    }

    // MARK: - Anchored patch schedule (pill → patch switch)

    func testAnchoredPatchPackKeepsChangeScheduleAlignedWithCycleDay() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, method: .patch, startDate: today)
        let pack = fixture.pack
        // Mid-cycle start: the user is on cycle day 5 when the pack begins today.
        pack.cycleDayAnchorIndex = 4

        let todayAction = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: pack))
        XCTAssertEqual(todayAction.cycleDay, pack.cycleDayIndex(on: today) + 1)
        XCTAssertEqual(todayAction.cycleDay, 5)
        XCTAssertEqual(todayAction.type, .patchActive)

        // Day 8 (three days out) is the next patch change — anchored to the user's
        // cycle, not to the pack's startDate.
        let day8 = try XCTUnwrap(DoseScheduleEngine.dueAction(on: day(3, from: today), pack: pack))
        XCTAssertEqual(day8.cycleDay, 8)
        XCTAssertEqual(day8.type, .patchChange)

        // Day 22 is the removal day.
        let day22 = try XCTUnwrap(DoseScheduleEngine.dueAction(on: day(17, from: today), pack: pack))
        XCTAssertEqual(day22.cycleDay, 22)
        XCTAssertEqual(day22.type, .patchRemove)
    }

    func testUnanchoredRingInsertAndWrappedReinsertUnchanged() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let insertFixture = try InMemoryStoreFactory.makeStore(now: today, method: .ring, startDate: today)
        let insert = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: insertFixture.pack))
        XCTAssertEqual(insert.type, .ringInsert)

        let reinsertFixture = try InMemoryStoreFactory.makeStore(
            now: today,
            method: .ring,
            startDate: day(-28, from: today)
        )
        let reinsert = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: reinsertFixture.pack))
        XCTAssertEqual(reinsert.type, .ringReinsert)
    }

    // MARK: - Refill timing honors the anchor

    func testAnchoredPackBecomesRefillDueWhenCycleCompletes() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            method: .patch,
            startDate: day(-1, from: today)
        )
        // Started yesterday on cycle day 28: one elapsed day completes the cycle.
        fixture.pack.cycleDayAnchorIndex = 27

        XCTAssertEqual(fixture.pack.elapsedCycleDays(on: today), 28)
        XCTAssertTrue(fixture.store.isRefillDue)
        XCTAssertEqual(fixture.store.daysOverdue, 0)
    }

    // MARK: - No phantom days after a completed cycle

    func testGapDaysAfterCompletedCycleAreNoDataNotMissed() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-11") // 30 days ago
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        // The 21/7 cycle ended two days ago (elapsed 28 on 2026-06-08).
        XCTAssertTrue(store.isRefillDue)
        XCTAssertEqual(store.daysOverdue, 2)

        // Gap days between cycle end and the new pack carry no tracking data —
        // the schedule engine's wrap is a forward-looking prediction only.
        XCTAssertEqual(store.statusForDate(day(-2, from: today)), .noData)
        XCTAssertEqual(store.statusForDate(day(-1, from: today)), .noData)

        // Inside the finished cycle nothing changes: unlogged active days are still
        // missed, break days still break days.
        XCTAssertEqual(store.statusForDate(day(-10, from: today)), .missed)
        XCTAssertEqual(store.statusForDate(day(-3, from: today)), .breakDay)

        // Today and later keep the wrapped prediction.
        XCTAssertEqual(store.statusForDate(today), .upcoming)

        // Gap days no longer count toward month adherence: Jun 1–7 were break days,
        // Jun 8–9 are gap days (skipped), so only today registers as due.
        let adherence = store.monthAdherence(for: today)
        XCTAssertEqual(adherence.due, 1)
        XCTAssertEqual(adherence.completed, 0)
    }

    // MARK: - Cycle-day edit keeps today's check-in

    func testUpdateCycleDayPreservesTodaysTakenLog() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let startDate = day(-4, from: today)
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        store.markTodayAsTaken()
        XCTAssertTrue(store.isTodayTaken)

        store.updateCycleDay(10)

        XCTAssertEqual(store.currentDayIndex + 1, 10)
        XCTAssertTrue(store.isTodayTaken, "Adjusting the cycle day must not undo today's check-in")
        XCTAssertEqual(store.statusForDate(day(-1, from: today)), .taken)
    }

    func testUpdateCycleDayWithoutTodayLogStaysUntaken() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: day(-4, from: today))
        let store = fixture.store

        store.updateCycleDay(10)

        XCTAssertFalse(store.isTodayTaken)
        XCTAssertEqual(store.statusForDate(today), .upcoming)
    }

    // MARK: - Method switch preserving history

    func testMethodSwitchPreservingHistoryShowsOldPackRecordsInCycleStrip() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let startDate = day(-10, from: today)
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        // Log the pill for the last few days on the old pack.
        for offset in -5...(-1) {
            store.markActionAsTaken(on: day(offset, from: today))
        }

        // Switch to the patch mid-cycle (day 11), preserving history.
        let accepted = store.startNewProtocol(
            method: .patch,
            regimen: .twentyOneSeven,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 11,
            preserveHistory: true
        )
        XCTAssertTrue(accepted)
        XCTAssertEqual(store.pack.method, .patch)

        // The engine, calendar, and strip agree that today is cycle day 11.
        XCTAssertEqual(store.currentDayIndex + 1, 11)
        let todayAction = try XCTUnwrap(store.dueAction(on: today))
        XCTAssertEqual(todayAction.cycleDay, 11)

        // Cycle completes 17 days from now (day 28), not 28 days from now.
        XCTAssertEqual(store.pack.elapsedCycleDays(on: day(17, from: today)), 27)
        XCTAssertEqual(store.pack.elapsedCycleDays(on: day(18, from: today)), 28)

        // Strip indices before the switch resolve to the old pack's real records
        // instead of phantom misses.
        let takenIndex = 7 // cycle day 8 = three days ago, logged above
        let snapshot = try XCTUnwrap(store.scheduleSnapshot(forCycleIndex: takenIndex, in: store.pack))
        XCTAssertEqual(snapshot.status, .taken)
    }

    // MARK: - Day rollover invalidates today-relative statuses

    func testDayRolloverRefreshRecomputesYesterdayAsMissed() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-10")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: today)
        let store = fixture.store

        // Cache today's snapshot while it is still "today".
        XCTAssertEqual(store.statusForDate(today), .upcoming)

        // Cross midnight without any store mutation.
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.fixedDate("2026-06-11"))
        let versionBefore = store.protocolChangeVersion
        store.refreshDayContextIfNeeded()

        XCTAssertEqual(store.statusForDate(today), .missed, "Yesterday's untaken pill must become missed after rollover")
        XCTAssertGreaterThan(store.protocolChangeVersion, versionBefore)

        // A second call on the same day is a no-op.
        let versionAfter = store.protocolChangeVersion
        store.refreshDayContextIfNeeded()
        XCTAssertEqual(store.protocolChangeVersion, versionAfter)
    }
}
