//
//  PlusAccessStateTests.swift
//  PillieTests
//
//  Exhaustive truth-table tests for Plus Access — the single predicate every
//  Pillie Plus feature gates on: entitlement || active Reverse Trial
//  (PRD #159 / ADR 0007 / issue #160, CONTEXT.md "Plus Access").
//

import XCTest

@testable import Pillie

final class PlusAccessStateTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }()

    /// 2026-07-20 12:00 Paris.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
    }

    /// Granted 2026-07-10 → active at `now` (day 10 of 14).
    private var activeGrant: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 9))!
    }

    /// Granted 2026-05-01 → long expired at `now`.
    private var expiredGrant: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9))!
    }

    private func access(entitlement: Bool, grant: Date?) -> Bool {
        PlusAccessState(hasEntitlement: entitlement, trialGrantDate: grant)
            .hasPlusAccess(calendar: calendar, now: now)
    }

    // MARK: - Truth table

    func testNoEntitlementAndNoTrialHasNoAccess() {
        XCTAssertFalse(access(entitlement: false, grant: nil))
    }

    func testEntitlementAloneGrantsAccess() {
        XCTAssertTrue(access(entitlement: true, grant: nil))
    }

    func testTrialWinsWithNoEntitlement() {
        XCTAssertTrue(access(entitlement: false, grant: activeGrant))
    }

    func testEntitlementAndActiveTrialGrantsAccess() {
        XCTAssertTrue(access(entitlement: true, grant: activeGrant))
    }

    func testExpiredTrialAloneHasNoAccess() {
        XCTAssertFalse(access(entitlement: false, grant: expiredGrant))
    }

    func testRealEntitlementWinsOverExpiredTrial() {
        XCTAssertTrue(access(entitlement: true, grant: expiredGrant))
    }

    // MARK: - Trial activity is derived, never stored

    func testTrialActiveIsDerivedFromClock() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: activeGrant)
        XCTAssertTrue(state.trialActive(calendar: calendar, now: now))

        let expired = PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant)
        XCTAssertFalse(expired.trialActive(calendar: calendar, now: now))

        let ungranted = PlusAccessState(hasEntitlement: false, trialGrantDate: nil)
        XCTAssertFalse(ungranted.trialActive(calendar: calendar, now: now))
    }
}
