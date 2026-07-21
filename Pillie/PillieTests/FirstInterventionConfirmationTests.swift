//
//  FirstInterventionConfirmationTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

final class FirstInterventionConfirmationTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: 12))!
    }

    func testFirstNonzeroFlushDuringActiveTrialPresentsConfirmation() {
        var counter = BlockerInterventionCounter()
        counter.recordIntercept()
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(1)
        )

        XCTAssertTrue(FirstInterventionConfirmation.shouldPresent(
            flushedCount: counter.flush(),
            state: state,
            alreadyShown: false,
            calendar: calendar,
            now: date(2)
        ))
    }

    func testZeroFlushDoesNotFabricateAnIntervention() {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(1)
        )

        XCTAssertFalse(FirstInterventionConfirmation.shouldPresent(
            flushedCount: 0,
            state: state,
            alreadyShown: false,
            calendar: calendar,
            now: date(2)
        ))
    }

    func testConfirmationIsNotPresentedAfterItWasAlreadyShown() {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(1)
        )

        XCTAssertFalse(FirstInterventionConfirmation.shouldPresent(
            flushedCount: 2,
            state: state,
            alreadyShown: true,
            calendar: calendar,
            now: date(2)
        ))
    }

    func testSubscriberDoesNotReceiveActiveTrialConfirmation() {
        let state = PlusAccessState(
            hasEntitlement: true,
            trialGrantDate: date(1)
        )

        XCTAssertFalse(FirstInterventionConfirmation.shouldPresent(
            flushedCount: 1,
            state: state,
            alreadyShown: false,
            calendar: calendar,
            now: date(2)
        ))
    }

    func testExpiredTrialDoesNotReceiveActiveTrialConfirmation() {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(1)
        )

        XCTAssertFalse(FirstInterventionConfirmation.shouldPresent(
            flushedCount: 1,
            state: state,
            alreadyShown: false,
            calendar: calendar,
            now: date(16)
        ))
    }

    func testMissingTrialGrantDoesNotReceiveActiveTrialConfirmation() {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: nil
        )

        XCTAssertFalse(FirstInterventionConfirmation.shouldPresent(
            flushedCount: 1,
            state: state,
            alreadyShown: false,
            calendar: calendar,
            now: date(2)
        ))
    }
}
