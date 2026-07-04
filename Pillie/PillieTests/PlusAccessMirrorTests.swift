//
//  PlusAccessMirrorTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the App Group
//  Plus Access mirror (issue #167 / ADR 0007): the coarse access-valid-until
//  date the main app derives for the shield/DeviceActivity side, so blocking
//  can never outlive Plus Access even if the app is never opened after expiry.
//  Mirrors ReverseTrialClockTests.
//

import XCTest

@testable import Pillie

final class PlusAccessMirrorTests: XCTestCase {

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

    // MARK: - Entitled users never expire

    func testEntitledAccessNeverExpires() {
        // Even with an expired trial grant on record, a real entitlement means
        // the shield side must never self-disable (AC: entitled-user never expires).
        let entitledWithStaleGrant = PlusAccessState(
            hasEntitlement: true,
            trialGrantDate: date(2026, 1, 1, 10, 0)
        )
        let entitledNoGrant = PlusAccessState(hasEntitlement: true, trialGrantDate: nil)

        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: entitledWithStaleGrant, calendar: calendar),
            .distantFuture
        )
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: entitledNoGrant, calendar: calendar),
            .distantFuture
        )
    }

    // MARK: - Tracer bullet: trial-only access mirrors the clock's expiry moment

    func testTrialOnlyAccessIsValidUntilClockExpiryMoment() {
        // Granted 2026-07-01: full days July 2–15, expiry 2026-07-16 00:00 local.
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(2026, 7, 1, 14, 30)
        )

        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: state, calendar: calendar),
            date(2026, 7, 16, 0, 0)
        )
    }

    // MARK: - No access at all

    func testNoEntitlementAndNoGrantIsNeverValid() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: nil)
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: state, calendar: calendar),
            .distantPast
        )
    }

    // MARK: - DST: the mirror stays at local midnight, matching the clock

    func testMirrorMatchesClockExpiryAcrossSpringForward() {
        // Paris springs forward 2026-03-29 (23-hour day inside the trial): the
        // mirrored date must be the local-midnight expiry, not grant + N×86400s.
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(2026, 3, 20, 21, 0)
        )
        let mirrored = PlusAccessMirror.validUntil(state: state, calendar: calendar)

        XCTAssertEqual(mirrored, date(2026, 4, 4, 0, 0))
        XCTAssertTrue(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: mirrored.timeIntervalSince1970,
            now: date(2026, 4, 3, 23, 59)
        ))
        XCTAssertFalse(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: mirrored.timeIntervalSince1970,
            now: date(2026, 4, 4, 0, 0)
        ))
    }

    // MARK: - Shield-side validity check (what the extension evaluates)

    func testBlockingIsAllowedStrictlyBeforeValidUntilAndNeverAfter() {
        let expiry = date(2026, 7, 16, 0, 0)

        // Last minute of day 14 is still protected.
        XCTAssertTrue(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: expiry.timeIntervalSince1970,
            now: date(2026, 7, 15, 23, 59)
        ))
        // The expiry moment itself ends blocking exactly (matches the clock).
        XCTAssertFalse(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: expiry.timeIntervalSince1970,
            now: expiry
        ))
        XCTAssertFalse(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: expiry.timeIntervalSince1970,
            now: date(2026, 8, 1, 9, 0)
        ))
    }

    func testMissingMirrorFailsTowardBlocking() {
        // A legacy install that predates the mirror has no key yet: the main app
        // writes it on the next open, and until then the pre-#167 behavior holds.
        // Same convention as TodayTakenStamp's missing day stamp.
        XCTAssertTrue(PlusAccessMirror.allowsBlocking(
            validUntilEpochSeconds: nil,
            now: date(2026, 7, 16, 0, 0)
        ))
    }
}
