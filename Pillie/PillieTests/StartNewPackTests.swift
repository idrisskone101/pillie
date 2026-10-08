//
//  StartNewPackTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

@MainActor
final class StartNewPackTests: XCTestCase {
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

    private func setNow(_ iso: String, hour: Int, minute: Int = 0, store: PillStore) {
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate(iso, hour: hour, minute: minute))
        store.refreshDayContextIfNeeded()
    }

    private func makeStore(
        now iso: String,
        hour: Int,
        minute: Int = 0,
        method: ContraceptiveMethod = .pill,
        regimen: PillPack.PillRegimenPreset = .twentyOneSeven,
        startDate: String,
        reminderHour: Int
    ) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(iso, hour: hour, minute: minute),
            method: method,
            regimen: regimen,
            startDate: day(startDate)
        )
        fixture = made
        made.store.reminderHour = reminderHour
        return made.store
    }

    /// 21-only pack from 10 Sep with a 9 PM reminder: 7 Oct is its last pill-free day.
    func testStartingANewPackBeforeTheEveningReminderStartsTonightsPill() throws {
        let store = try makeStore(now: "2026-10-08", hour: 10, regimen: .twentyOneOnly, startDate: "2026-09-10", reminderHour: 21)

        store.startNewPack()

        XCTAssertEqual(store.today, day("2026-10-08"))
        XCTAssertEqual(store.currentDayIndex + 1, 1)
        XCTAssertEqual(store.doseStanding(on: store.today), .upcoming)
        XCTAssertEqual(store.scheduleSnapshot(for: day("2026-10-07"))?.pack.packNumber, 1)

        setNow("2026-10-09", hour: 21, minute: 30, store: store)

        XCTAssertEqual(store.currentDayIndex + 1, 2)
    }

    /// 21/7 pack from 10 Sep with a 9 PM reminder: day 28 is 7 Oct, so 8 Oct is the first day after it.
    func testACheckInAfterThePackEndsSurvivesStartingTheNewPack() throws {
        let store = try makeStore(now: "2026-10-08", hour: 21, minute: 30, startDate: "2026-09-10", reminderHour: 21)
        XCTAssertTrue(store.isRefillDue)
        store.markActionAsTaken(on: store.today)
        XCTAssertTrue(store.isTodayTaken)

        setNow("2026-10-09", hour: 10, store: store)
        store.startNewPack()

        XCTAssertEqual(store.statusForDate(day("2026-10-08")), .taken)
        XCTAssertEqual(store.currentDayIndex + 1, 1)
        XCTAssertTrue(store.isTodayTaken)
        XCTAssertFalse(store.isRefillDue)
    }

    func testDaysOfCheckInsAfterThePackEndKeepThePillNumber() throws {
        let store = try makeStore(now: "2026-10-08", hour: 21, minute: 30, startDate: "2026-09-10", reminderHour: 21)
        for date in ["2026-10-08", "2026-10-09", "2026-10-10"] {
            setNow(date, hour: 21, minute: 30, store: store)
            store.markActionAsTaken(on: store.today)
        }

        setNow("2026-10-11", hour: 22, store: store)
        store.startNewPack()

        XCTAssertEqual(store.currentDayIndex + 1, 4)
        XCTAssertEqual(store.statusForDate(day("2026-10-08")), .taken)
        XCTAssertEqual(store.statusForDate(day("2026-10-10")), .taken)
        XCTAssertEqual(store.currentStreak, 3)
    }

    /// Ring from 1 May with a 9 PM reminder: day 29, the reinsert, is 29 May.
    func testARingReinsertLoggedAfterMidnightStartsTheCycleOnItsDay() throws {
        let store = try makeStore(now: "2026-05-30", hour: 1, method: .ring, startDate: "2026-05-01", reminderHour: 21)
        XCTAssertEqual(store.todayDueAction?.type, .ringReinsert)

        store.markTodayAsTaken()

        XCTAssertEqual(store.activePack?.packNumber, 2)
        XCTAssertEqual(store.activePack?.startDate, day("2026-05-29"))
        XCTAssertTrue(store.isTodayTaken)
    }

    /// Ring from 1 May with an 8 AM reminder: 31 May is two days past the reinsert.
    func testUndoingTheInsertOnAStartedRingCycleKeepsTheCycle() throws {
        let store = try makeStore(now: "2026-05-31", hour: 9, method: .ring, startDate: "2026-05-01", reminderHour: 8)
        store.startNewPack()
        store.markTodayAsTaken()

        store.unmarkTodayAsTaken()

        XCTAssertEqual(store.activePack?.packNumber, 2)
        XCTAssertFalse(store.isRefillDue)
        XCTAssertEqual(store.todayDueAction?.type, .ringInsert)
    }

    /// Home's pack card title and subtitle, as the card reads them from the store.
    private func homePackHeader(_ store: PillStore) -> [String] {
        let english = Locale(identifier: "en")
        let progress = HomePackProgress.live(store: store, isTodayTaken: store.isTodayTaken, now: PillieClock.now)
        return [progress.title(locale: english), progress.subtitle(reminderTime: "9:00 PM", locale: english)]
    }

    /// Every day pack from 10 Sep with a 9 PM reminder: pill 28 was due on 7 Oct and never logged.
    func testAnEveryDayPacksMissedLastPillShowsOnHomeBeforeAndAfterStartingANewPack() throws {
        let store = try makeStore(now: "2026-10-08", hour: 21, minute: 30, regimen: .everyDay, startDate: "2026-09-10", reminderHour: 21)
        for offset in 0..<27 {
            store.markActionAsTaken(on: Calendar.current.date(byAdding: .day, value: offset, to: day("2026-09-10"))!)
        }
        XCTAssertEqual(store.statusForDate(day("2026-10-07")), .missed)

        XCTAssertEqual(homePackHeader(store), ["Pack finished", "Pill 28 not checked in yesterday"])

        store.startNewPack()

        XCTAssertEqual(homePackHeader(store), ["Pill 1 of 28", "Pill 28 not checked in yesterday"])
    }
}
