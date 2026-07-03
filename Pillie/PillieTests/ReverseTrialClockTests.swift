//
//  ReverseTrialClockTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the Reverse Trial
//  clock — the pure Date/Time Boundary seam behind Plus Access (PRD #159 /
//  ADR 0007 / issue #160). Mirrors ReviewPromptEligibilityTests.
//

import XCTest

@testable import Pillie

final class ReverseTrialClockTests: XCTestCase {

    /// Fixed local calendar so boundary expectations are deterministic.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        let cal = calendar ?? self.calendar
        return cal.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    // MARK: - Tracer bullet: a freshly granted trial is active

    func testTrialIsActiveImmediatelyAfterGrant() {
        let grant = date(2026, 7, 1, 14, 30)
        let clock = ReverseTrialClock(grantDate: grant)
        XCTAssertTrue(clock.isActive(calendar: calendar, now: grant))
    }

    // MARK: - Grant at 23:59 still gets 14 full days (day-14 midnight edge)

    func testLateEveningGrantStillCoversFourteenFullDays() {
        // Granted 2026-07-01 23:59. The grant day is a partial bonus day; the 14
        // full days are July 2–15, so the trial expires at 2026-07-16 00:00.
        let clock = ReverseTrialClock(grantDate: date(2026, 7, 1, 23, 59))

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 16, 0, 0))
        // Last minute of day 14 is still protected ("tonight" is honest copy).
        XCTAssertTrue(clock.isActive(calendar: calendar, now: date(2026, 7, 15, 23, 59)))
        // The local-day rollover after day 14 ends the trial exactly.
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 7, 16, 0, 0)))
    }

    // MARK: - Days remaining (count of local-day rollovers until expiry)

    func testDaysRemainingCountsRolloversAndClampsAtZero() {
        // Granted 2026-07-01 23:59 → full days July 2–15, expiry July 16 00:00.
        let clock = ReverseTrialClock(grantDate: date(2026, 7, 1, 23, 59))

        // On the partial grant day the 14 full days are all still ahead,
        // plus tonight's rollover: 15.
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 1, 23, 59)), 15)
        // First full day: 14 rollovers left.
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 2, 9, 0)), 14)
        // Last protected day reads 1 — "expires tonight" is honest.
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 15, 22, 0)), 1)
        // Expired trials never go negative.
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 16, 0, 0)), 0)
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 8, 20, 12, 0)), 0)
    }

    // MARK: - DST transitions (expiry stays at local midnight, not +N×86400s)

    func testExpiryStaysAtLocalMidnightAcrossSpringForward() {
        // Paris springs forward 2026-03-29 (23-hour day inside the trial).
        let clock = ReverseTrialClock(grantDate: date(2026, 3, 20, 21, 0))

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 4, 4, 0, 0))
        XCTAssertTrue(clock.isActive(calendar: calendar, now: date(2026, 4, 3, 23, 59)))
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 4, 4, 0, 0)))
        // Rollover count is unaffected by the missing hour.
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 3, 30, 10, 0)), 5)
    }

    func testExpiryStaysAtLocalMidnightAcrossFallBack() {
        // Paris falls back 2026-10-25 (25-hour day inside the trial).
        let clock = ReverseTrialClock(grantDate: date(2026, 10, 15, 8, 0))

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 10, 30, 0, 0))
        XCTAssertTrue(clock.isActive(calendar: calendar, now: date(2026, 10, 29, 23, 59)))
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 10, 30, 0, 0)))
    }

    // MARK: - Month and year boundaries

    func testTrialSpansMonthBoundary() {
        // Granted 2026-01-25 → full days Jan 26 – Feb 8 (6 + 8), expiry Feb 9 00:00.
        let clock = ReverseTrialClock(grantDate: date(2026, 1, 25, 10, 0))
        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 2, 9, 0, 0))
    }

    func testTrialSpansYearBoundary() {
        // Granted 2026-12-26 → full days Dec 27 – Jan 9 (5 + 9), expiry Jan 10 00:00.
        let clock = ReverseTrialClock(grantDate: date(2026, 12, 26, 18, 30))

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2027, 1, 10, 0, 0))
        XCTAssertTrue(clock.isActive(calendar: calendar, now: date(2027, 1, 9, 12, 0)))
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2027, 1, 10, 0, 0)))
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2027, 1, 1, 0, 0)), 9)
    }
}
