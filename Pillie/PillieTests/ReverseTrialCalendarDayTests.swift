//
//  ReverseTrialCalendarDayTests.swift
//  PillieTests
//
//  ENG-242: a calendar-day trial counts 14 calendar days. An active-day trial
//  keeps its saved ledger and freezes over breaks.
//

import Foundation
import Testing

@testable import Pillie

@MainActor
struct ReverseTrialCalendarDayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    /// Granted on pill 21 of a 21/7 pack; July 2-8 are the sugar week.
    private var grant: Date { date(7, 1, 10) }

    private var twentyOneSeven: ActiveDaySchedule {
        ActiveDaySchedule(anchorDate: date(7, 1), anchorDayIndex: 20, activeDays: 21, cycleLength: 28)
    }

    @Test func newGrantEndsAtMidnightStartingCalendarDay15AcrossABreakWeek() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: grant)
        let clock = state.trialClock!

        #expect(clock.expiryMoment(calendar: calendar) == date(7, 16))
        #expect(clock.daysRemaining(calendar: calendar, now: date(7, 5, 12)) == 11)
        #expect(clock.endsTonight(calendar: calendar, now: date(7, 15, 12)))
        #expect(state.hasPlusAccess(calendar: calendar, now: date(7, 15, 23)))
        #expect(!state.hasPlusAccess(calendar: calendar, now: date(7, 16)))
    }

    @Test func newGrantShowsFourteenDaysOnGrantDay() {
        let clock = PlusAccessState(hasEntitlement: false, trialGrantDate: grant).trialClock!

        #expect(clock.daysRemaining(calendar: calendar, now: grant) == 15)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: grant) == 14)
    }

    @Test func ledgerBackedTrialStillFreezesAcrossItsBreak() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: grant, schedule: twentyOneSeven)
        let clock = state.trialClock!

        #expect(clock.expiryMoment(calendar: calendar) == date(7, 23))
        #expect(clock.daysRemaining(calendar: calendar, now: date(7, 2, 12)) == 14)
        #expect(clock.daysRemaining(calendar: calendar, now: date(7, 8, 12)) == 14)
        #expect(state.hasPlusAccess(calendar: calendar, now: date(7, 20, 12)))
    }

    @Test func ledgerBackedTrialSwitchedMidBreakNeverCountsTheLivedBreak() {
        let ledger = TrialDayLedger(
            schedule: twentyOneSeven,
            lived: nil,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
        .adopting(.everyCalendarDay, grantDate: grant, calendar: calendar, now: date(7, 5, 12))
        let clock = ReverseTrialClock(grantDate: grant, schedule: ledger.schedule, lived: ledger.lived)

        #expect(ledger.lived == TrialLivedDays(since: date(7, 5), activeDays: 0))
        #expect(clock.expiryMoment(calendar: calendar) == date(7, 19))
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}
