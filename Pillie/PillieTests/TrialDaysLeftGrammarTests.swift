//
//  TrialDaysLeftGrammarTests.swift
//  PillieTests
//
//  A break right before the trial's last active day freezes the count at 1
//  for up to a week. Every surface that names the count must then read it in
//  the singular: the Home badge, the Plus-on badge, the paywall, and the
//  blocking step's trial line.
//

import XCTest

@testable import Pillie

final class TrialDaysLeftGrammarTests: XCTestCase {

    private let english = Locale(identifier: "en_US")

    func testOneActiveDayLeftReadsInTheSingular() throws {
        let (state, now) = lastActiveDayBehindABreak()
        let badge = try XCTUnwrap(TrialStatusPresentation.make(
            state: state, calendar: .current, now: now, locale: english
        ))
        let plusOnBadge = try XCTUnwrap(TrialStatusPresentation.make(
            state: state, protectionActive: true, calendar: .current, now: now, locale: english
        ))

        XCTAssertEqual(badge.daysRemaining, 1)
        XCTAssertEqual(badge.countdownLabel, "1 active day left")
        XCTAssertEqual(plusOnBadge.indicatorLabel, "Plus is on · 1 active day left")
        XCTAssertEqual(
            HonestPaywallStoryFactory.duringTrial(
                daysRemaining: badge.daysRemaining,
                endsTonight: badge.endsTonight,
                locale: english
            ).subtitle,
            "You have 1 active day left. Pick a plan now and nothing turns off on day 14."
        )
        XCTAssertEqual(
            AppBlockingSetupContent.localized(locale: english, trialClock: state.trialClock, now: now).trialLine,
            "Pillie Plus is on for your next 1 active day, free. No\u{00A0}card. We’ll remind you before it ends."
        )
    }

    func testOtherLanguagesAgreeWithTheCount() throws {
        let (state, now) = lastActiveDayBehindABreak()
        func badge(_ identifier: String) throws -> String {
            try XCTUnwrap(TrialStatusPresentation.make(
                state: state, calendar: .current, now: now, locale: Locale(identifier: identifier)
            )).countdownLabel
        }
        func trialLine(_ identifier: String) -> String {
            AppBlockingSetupContent.localized(
                locale: Locale(identifier: identifier), trialClock: state.trialClock, now: now
            ).trialLine
        }

        XCTAssertEqual(try badge("de"), "Noch 1 aktiver Tag")
        XCTAssertEqual(try badge("fr"), "Encore 1 jour actif")
        XCTAssertEqual(trialLine("ru"), "Pillie Plus бесплатно на следующий 1 активный день. Без карты. Напомним до окончания.")
        // Fourteen still reads in the plural.
        XCTAssertEqual(
            try XCTUnwrap(TrialStatusPresentation.make(
                state: state, calendar: .current, now: day(7, 2, 9), locale: english
            )).countdownLabel,
            "14 active days left"
        )
    }

    /// 21/7, granted on pack day 8: July 2-14 are 13 counted days, July 15-21
    /// the break, and July 22 the 14th. Noon on July 15 is inside the break.
    private func lastActiveDayBehindABreak() -> (PlusAccessState, Date) {
        let grant = day(7, 1, 9)
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: grant,
            schedule: ActiveDaySchedule(anchorDate: grant, anchorDayIndex: 7, activeDays: 21, cycleLength: 28)
        )
        return (state, day(7, 15, 12))
    }

    private func day(_ month: Int, _ day: Int, _ hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}
