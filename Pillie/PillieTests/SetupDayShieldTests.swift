//
//  SetupDayShieldTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// What the DeviceActivity extension decides from the App Group state the app writes
/// on a day set up before its first reminder. Shields wait for that reminder.
@MainActor
final class SetupDayShieldTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?

    override func tearDown() {
        fixture = nil
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private func at(_ hour: Int, minute: Int = 0) -> Date {
        InMemoryStoreFactory.localDate("2026-10-07", hour: hour, minute: minute)
    }

    /// Set up at 10:00 AM with a 9:00 PM reminder; the routine's day `cycleDay` is the
    /// calendar day and the day before it is backfilled as done.
    private func storeSetUpBeforeTheReminder(
        method: ContraceptiveMethod = .pill,
        cycleDay: Int,
        answer: TodayPillPick.Answer?
    ) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(now: at(10), method: method)
        fixture = made
        let store = made.store
        store.reminderHour = 21
        store.resetAndStartFresh(
            method: method,
            regimen: .twentyOneSeven,
            customRegimen: nil,
            cycleDay: cycleDay,
            anchorDay: store.anchorDay(for: answer)
        )
        return store
    }

    private func extensionDecision(_ store: PillStore, at now: Date) -> BlockingInterventionDecision {
        store.syncTodayTakenToAppGroup()
        let time = ScreenTimeSharedState.reminderTime()
        return BlockingInterventionPolicy.decision(
            schedule: ScreenTimeSharedState.blockingScheduleMirror,
            handledStamp: ScreenTimeSharedState.todayTakenStamp,
            now: now,
            reminderHour: time.hour,
            reminderMinute: time.minute
        )
    }

    func testNoShieldsBeforeTheFirstReminder() throws {
        let store = try storeSetUpBeforeTheReminder(cycleDay: 12, answer: .notYet)

        XCTAssertEqual(extensionDecision(store, at: at(10, minute: 5)), .clearShields)
    }

    func testLoggingBeforeTheFirstReminderKeepsShieldsDown() throws {
        let store = try storeSetUpBeforeTheReminder(cycleDay: 12, answer: .notYet)

        store.markTodayAsTaken()

        XCTAssertEqual(extensionDecision(store, at: at(12)), .clearShields)
    }

    func testShieldsComeAtTheReminderWhenThePillIsUntaken() throws {
        let store = try storeSetUpBeforeTheReminder(cycleDay: 12, answer: .notYet)
        PillieClock.setFixedNowForTesting(at(21))
        store.refreshDayContextIfNeeded()

        XCTAssertEqual(extensionDecision(store, at: at(21)), .applyShields)
    }

    func testNoShieldsOnAPatchWearingDaySetUpBeforeItsReminder() throws {
        let store = try storeSetUpBeforeTheReminder(method: .patch, cycleDay: 2, answer: nil)

        XCTAssertEqual(extensionDecision(store, at: at(10, minute: 5)), .clearShields)
    }
}
