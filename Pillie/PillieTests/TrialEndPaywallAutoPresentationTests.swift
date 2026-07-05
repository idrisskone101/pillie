//
//  TrialEndPaywallAutoPresentationTests.swift
//  PillieTests
//
//  Value-type unit tests for the Trial-End Paywall's exactly-once auto-present
//  decision (issue #169 / ADR 0007): shown on the first launch at-or-after
//  Reverse Trial expiry, never auto-repeated after dismissal — the Protection
//  Off card is the way back. Mirrors TrialExpiredEventTests.
//

import XCTest

@testable import Pillie

final class TrialEndPaywallAutoPresentationTests: XCTestCase {

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

    // Granted 2026-06-21 → expiry 2026-07-06 00:00.
    private func state(hasEntitlement: Bool = false, granted: Bool = true) -> PlusAccessState {
        PlusAccessState(
            hasEntitlement: hasEntitlement,
            trialGrantDate: granted ? date(2026, 6, 21, 10, 0) : nil
        )
    }

    private var firstExpiredMorning: Date { date(2026, 7, 6, 9, 0) }

    func testPresentsOnFirstOpenAtOrAfterExpiry() {
        XCTAssertTrue(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(),
            entitlementResolved: true,
            alreadyShown: false,
            calendar: calendar,
            now: firstExpiredMorning
        ))
    }

    func testNeverAutoRepeatsOnceShown() {
        XCTAssertFalse(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(),
            entitlementResolved: true,
            alreadyShown: true,
            calendar: calendar,
            now: firstExpiredMorning
        ))
    }

    func testDefersWhileEntitlementIsUnresolved() {
        // `hasEntitlement` starts false before RevenueCat resolves — deciding
        // early would misread a mid-trial converter as expired (#167 seam).
        XCTAssertFalse(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(),
            entitlementResolved: false,
            alreadyShown: false,
            calendar: calendar,
            now: firstExpiredMorning
        ))
    }

    func testNothingWhileTrialIsActive() {
        XCTAssertFalse(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(),
            entitlementResolved: true,
            alreadyShown: false,
            calendar: calendar,
            now: date(2026, 7, 5, 9, 0)
        ))
    }

    func testNothingForEntitledUsersAndUngrantedInstalls() {
        XCTAssertFalse(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(hasEntitlement: true),
            entitlementResolved: true,
            alreadyShown: false,
            calendar: calendar,
            now: firstExpiredMorning
        ))
        XCTAssertFalse(TrialEndPaywallAutoPresentation.shouldPresent(
            state: state(granted: false),
            entitlementResolved: true,
            alreadyShown: false,
            calendar: calendar,
            now: firstExpiredMorning
        ))
    }
}
