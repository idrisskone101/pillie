//
//  UndoBlockingTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// Undoing a log puts shields back only where reconcile would: after the live
/// day's reminder, with blocking switched on.
@MainActor
final class UndoBlockingTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?

    override func setUp() {
        super.setUp()
        SubscriptionManager.shared.setPlusForTesting(true)
        AppBlockingManager.shared.debugBlockerConfiguredOverride = true
    }

    override func tearDown() {
        fixture = nil
        AppBlockingManager.shared.blockingEnabled = true
        AppBlockingManager.shared.debugBlockerConfiguredOverride = nil
        AppBlockingManager.shared.removeBlocking()
        SubscriptionManager.shared.setPlusForTesting(false)
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    /// Noon on 7 Oct with an 8:00 AM reminder: today's pill is late.
    private func lateDoseStore() throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(now: InMemoryStoreFactory.localDate("2026-10-07", hour: 12))
        fixture = made
        return made.store
    }

    func testUndoingALateDoseShieldsAgain() throws {
        let store = try lateDoseStore()
        store.markTodayAsTaken()

        store.unmarkTodayAsTaken()

        XCTAssertTrue(ScreenTimeSharedState.isBlockingRequested)
    }

    func testUndoWithBlockingSwitchedOffShieldsNothing() throws {
        let store = try lateDoseStore()
        AppBlockingManager.shared.blockingEnabled = false
        store.markTodayAsTaken()

        store.unmarkTodayAsTaken()

        XCTAssertFalse(ScreenTimeSharedState.isBlockingRequested)
    }

    /// Set up at 10:00 AM with a 9:00 PM reminder, "not yet" on pill 12.
    func testUndoBeforeTheFirstReminderShieldsNothing() throws {
        let store = try lateDoseStore()
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-10-07", hour: 10))
        store.reminderHour = 21
        store.resetAndStartFresh(
            method: .pill,
            regimen: .twentyOneSeven,
            customRegimen: nil,
            cycleDay: 12,
            anchorDay: store.anchorDay(for: .notYet)
        )
        store.markTodayAsTaken()

        store.unmarkTodayAsTaken()

        XCTAssertFalse(ScreenTimeSharedState.isBlockingRequested)
    }
}
