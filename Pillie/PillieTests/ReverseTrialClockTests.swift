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
        XCTAssertTrue(clock.endsTonight(calendar: calendar, now: date(2026, 7, 15, 23, 59)))
        // The local-day rollover after day 14 ends the trial exactly.
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 7, 16, 0, 0)))
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 16, 0, 0)))
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 1, 23, 59)))
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

    func testDisplayedDaysRemainingNeverReadsAboveTheFourteenDayPromise() {
        let clock = ReverseTrialClock(grantDate: date(2026, 7, 1, 23, 59))

        XCTAssertEqual(
            clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 1, 23, 59)),
            14
        )
        XCTAssertEqual(
            clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 2, 9, 0)),
            14
        )
        XCTAssertEqual(
            clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 15, 22, 0)),
            1
        )
        XCTAssertEqual(ReverseTrialClock.displayedDaysRemaining(15), 14)
        XCTAssertEqual(ReverseTrialClock.displayedDaysRemaining(0), 0)
        XCTAssertEqual(ReverseTrialClock.displayedDaysRemaining(-1), 0)
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

    // MARK: - Active-phase days (21/7), grant on last active day then break

    func testGrantOnLastActiveDayThenBreak() {
        // Pack 21/7. Grant 2026-07-01 10:00 is cycle day index 20 (day 21).
        // Break is July 2-8. Next active block July 9-22 (14 full active days).
        let clock = ReverseTrialClock(
            grantDate: date(2026, 7, 1, 10, 0),
            schedule: twentyOneSeven(anchorDayIndex: 20, anchorDate: date(2026, 7, 1, 10, 0))
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 23, 0, 0))

        assertClock(
            clock,
            now: date(2026, 7, 1, 10, 0),
            isActive: true, daysRemaining: 15, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 2, 12, 0),
            isActive: true, daysRemaining: 14, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 8, 12, 0),
            isActive: true, daysRemaining: 14, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 9, 9, 0),
            isActive: true, daysRemaining: 14, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 22, 23, 59),
            isActive: true, daysRemaining: 1, displayed: 1, endsTonight: true
        )
        assertClock(
            clock,
            now: date(2026, 7, 23, 0, 0),
            isActive: false, daysRemaining: 0, displayed: 0, endsTonight: false
        )
    }

    // MARK: - Mid-trial break after 10 full active days

    func testMidTrialBreakFreezesBadge() {
        // Grant 2026-07-01 09:00 is cycle day index 10 (day 11).
        // Active July 1-11 (grant + 10 full), break July 12-18, then 4 more
        // full active July 19-22. Expiry 2026-07-23 00:00. Badge stays at 4
        // across the break.
        let clock = ReverseTrialClock(
            grantDate: date(2026, 7, 1, 9, 0),
            schedule: twentyOneSeven(anchorDayIndex: 10, anchorDate: date(2026, 7, 1, 9, 0))
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 23, 0, 0))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 1, 9, 0)), 15)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 1, 9, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 11, 12, 0)), 5)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 11, 12, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 12, 12, 0)), 4)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 12, 12, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 18, 12, 0)), 4)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 18, 12, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 22, 23, 59)), 1)
        XCTAssertTrue(clock.endsTonight(calendar: calendar, now: date(2026, 7, 22, 23, 59)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 23, 0, 0)), 0)
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 7, 23, 0, 0)))
    }

    // MARK: - Grant on a break day

    func testGrantOnBreakDay() {
        // Grant 2026-07-01 09:00 is cycle day index 21 (first break day).
        // Remaining break July 1-7. Then 14 full active July 8-21.
        // Expiry 2026-07-22 00:00.
        let clock = ReverseTrialClock(
            grantDate: date(2026, 7, 1, 9, 0),
            schedule: twentyOneSeven(anchorDayIndex: 21, anchorDate: date(2026, 7, 1, 9, 0))
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 22, 0, 0))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 1, 9, 0)), 15)
        XCTAssertEqual(clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 1, 9, 0)), 14)

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 2, 12, 0)), 14)
        XCTAssertEqual(clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 2, 12, 0)), 14)

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 8, 9, 0)), 14)
        XCTAssertEqual(clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 8, 9, 0)), 14)

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 21, 12, 0)), 1)
        XCTAssertEqual(clock.displayedDaysRemaining(calendar: calendar, now: date(2026, 7, 21, 12, 0)), 1)
        XCTAssertTrue(clock.endsTonight(calendar: calendar, now: date(2026, 7, 21, 12, 0)))
    }

    // MARK: - endsTonight is false on a break day with 1 active day left

    func testEndsTonightIsFalseOnBreakDayWithOneActiveDayLeft() {
        // Cycle day index 7 (pack day 8) on grant: 13 full active days, then
        // break July 15-21, then one last full active day on July 22.
        // On July 15 the badge is 1 but expiry is 2026-07-23 00:00, not tonight.
        let clock = ReverseTrialClock(
            grantDate: date(2026, 7, 1, 9, 0),
            schedule: twentyOneSeven(anchorDayIndex: 7, anchorDate: date(2026, 7, 1, 9, 0))
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 23, 0, 0))
        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 15, 12, 0)), 1)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 15, 12, 0)))
        XCTAssertTrue(clock.isActive(calendar: calendar, now: date(2026, 7, 15, 12, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 21, 12, 0)), 1)
        XCTAssertFalse(clock.endsTonight(calendar: calendar, now: date(2026, 7, 21, 12, 0)))

        XCTAssertEqual(clock.daysRemaining(calendar: calendar, now: date(2026, 7, 22, 12, 0)), 1)
        XCTAssertTrue(clock.endsTonight(calendar: calendar, now: date(2026, 7, 22, 12, 0)))
    }

    func testEmptyHormoneSetFailsTowardCalendarExpiry() {
        let grant = date(2026, 7, 1, 10, 0)
        let clock = ReverseTrialClock(
            grantDate: grant,
            schedule: ActiveDaySchedule(
                anchorDate: date(2026, 7, 1, 10, 0),
                anchorDayIndex: 0,
                cycleLength: 7,
                hormoneActiveIndices: []
            )
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 16, 0, 0))
        XCTAssertTrue(clock.isActive(calendar: calendar, now: grant))
        XCTAssertFalse(clock.isActive(calendar: calendar, now: date(2026, 7, 16, 0, 0)))
    }

    // MARK: - Patch remove day is hormone-active

    func testPatchGrantOnRemoveDayConsumesThenPausesOffWeek() {
        // Pack is patch 21/7. Grant 2026-07-01 10:00 is cycle day 22 (index 21).
        // `isBreakDay(21)` is true; engine `isBreak` is false. Off-week is
        // July 2-7 (days 23-28). Fourteen full actives start July 8.
        let schedule = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1, 10, 0),
            anchorDayIndex: 21,
            cycleLength: 28,
            hormoneActiveIndices: Set(0..<22)
        )
        let clock = ReverseTrialClock(
            grantDate: date(2026, 7, 1, 10, 0),
            schedule: schedule
        )

        XCTAssertEqual(clock.expiryMoment(calendar: calendar), date(2026, 7, 23, 0, 0))
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 1, 10, 0), calendar: calendar))
        XCTAssertFalse(schedule.isActiveDay(date(2026, 7, 2), calendar: calendar))

        assertClock(
            clock,
            now: date(2026, 7, 1, 10, 0),
            isActive: true, daysRemaining: 15, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 2, 12, 0),
            isActive: true, daysRemaining: 14, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 7, 12, 0),
            isActive: true, daysRemaining: 14, displayed: 14, endsTonight: false
        )
        assertClock(
            clock,
            now: date(2026, 7, 22, 23, 59),
            isActive: true, daysRemaining: 1, displayed: 1, endsTonight: true
        )
    }

    func testCycleEditRecomputesExpiryFromSameGrant() {
        let grant = date(2026, 7, 1, 10, 0)
        let lastActive = ReverseTrialClock(
            grantDate: grant,
            schedule: twentyOneSeven(anchorDayIndex: 20, anchorDate: grant)
        )
        let dayOne = ReverseTrialClock(
            grantDate: grant,
            schedule: twentyOneSeven(anchorDayIndex: 0, anchorDate: date(2026, 7, 2))
        )

        XCTAssertEqual(lastActive.expiryMoment(calendar: calendar), date(2026, 7, 23, 0, 0))
        XCTAssertEqual(dayOne.expiryMoment(calendar: calendar), date(2026, 7, 16, 0, 0))
    }

    func testGrantDatePlacingLastCountedDaySkipsBreakDays() {
        let now = date(2026, 7, 22, 18, 0)
        let schedule = twentyOneSeven(anchorDayIndex: 20, anchorDate: date(2026, 7, 1, 10, 0))
        let grant = ReverseTrialClock.grantDatePlacingLastCountedDay(
            now: now,
            calendar: calendar,
            schedule: schedule
        )

        // Fourteen full actives ending today are July 9-22; grant is the day
        // before that block (July 8, a break day). Plus still ends tonight.
        XCTAssertEqual(calendar.startOfDay(for: grant!), date(2026, 7, 8, 0, 0))
        let clock = ReverseTrialClock(grantDate: grant!, schedule: schedule)
        XCTAssertTrue(clock.endsTonight(calendar: calendar, now: now))
        XCTAssertNil(
            ReverseTrialClock.grantDatePlacingLastCountedDay(
                now: date(2026, 7, 8, 12, 0),
                calendar: calendar,
                schedule: schedule
            )
        )
    }

    private func twentyOneSeven(anchorDayIndex: Int, anchorDate: Date) -> ActiveDaySchedule {
        ActiveDaySchedule(
            anchorDate: anchorDate,
            anchorDayIndex: anchorDayIndex,
            activeDays: 21,
            cycleLength: 28
        )
    }

    private func assertClock(
        _ clock: ReverseTrialClock,
        now: Date,
        isActive: Bool,
        daysRemaining: Int,
        displayed: Int,
        endsTonight: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            clock.isActive(calendar: calendar, now: now),
            isActive,
            file: file,
            line: line
        )
        XCTAssertEqual(
            clock.daysRemaining(calendar: calendar, now: now),
            daysRemaining,
            file: file,
            line: line
        )
        XCTAssertEqual(
            clock.displayedDaysRemaining(calendar: calendar, now: now),
            displayed,
            file: file,
            line: line
        )
        XCTAssertEqual(
            clock.endsTonight(calendar: calendar, now: now),
            endsTonight,
            file: file,
            line: line
        )
    }
}
