//
//  TrialExpiredEventTests.swift
//  PillieTests
//
//  Value-type unit tests for the `trial_expired` one-shot decision (issue
//  #167 / ADR 0007): the event fires exactly once, on the first app open
//  at-or-after expiry, and never for entitled users. Mirrors
//  ExistingUserTrialGrantTests' one-shot-window style.
//

import XCTest

@testable import Pillie

final class TrialExpiredEventTests: XCTestCase {

    /// Fixed local calendar so boundary expectations are deterministic.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    /// Granted 2026-07-01 → expiry 2026-07-16 00:00 local.
    private var expiredGrant: Date { date(2026, 7, 1, 14, 30) }

    // MARK: - Tracer bullet: first open at-or-after expiry fires

    func testExpiredUnconvertedTrialFiresOnce() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant)

        XCTAssertTrue(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: true,
            alreadyFired: false,
            calendar: calendar,
            now: date(2026, 7, 16, 8, 0)
        ))
    }

    // MARK: - Unresolved entitlement defers (never misreads a payer as expired)

    func testUnresolvedEntitlementDefersFiring() {
        // Cold launch before the first RevenueCat customer-info fetch:
        // `hasEntitlement` still reads false for a mid-trial converter (#165's
        // seam). Defer — the window stays open and a later open fires instead.
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant)

        XCTAssertFalse(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: false,
            alreadyFired: false,
            calendar: calendar,
            now: date(2026, 7, 16, 8, 0)
        ))
    }

    // MARK: - Exactly once: the persisted flag suppresses every later open

    func testAlreadyFiredNeverFiresAgain() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant)

        XCTAssertFalse(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: true,
            alreadyFired: true,
            calendar: calendar,
            now: date(2026, 7, 17, 8, 0)
        ))
    }

    // MARK: - An active trial has not expired

    func testActiveTrialDoesNotFire() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant)

        // Last protected minute of day 14.
        XCTAssertFalse(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: true,
            alreadyFired: false,
            calendar: calendar,
            now: date(2026, 7, 15, 23, 59)
        ))
    }

    // MARK: - Entitled users never expire

    func testEntitledUserNeverFiresEvenPastGrantWindow() {
        // Converted mid-trial: the trial window ending is invisible — Plus
        // Access never flipped, so nothing "expired" for this user.
        let state = PlusAccessState(hasEntitlement: true, trialGrantDate: expiredGrant)

        XCTAssertFalse(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: true,
            alreadyFired: false,
            calendar: calendar,
            now: date(2026, 8, 1, 9, 0)
        ))
    }

    // MARK: - No grant, nothing to expire

    func testNeverGrantedUserNeverFires() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: nil)

        XCTAssertFalse(TrialExpiredEvent.shouldFire(
            state: state,
            entitlementResolved: true,
            alreadyFired: false,
            calendar: calendar,
            now: date(2026, 7, 16, 8, 0)
        ))
    }
}
