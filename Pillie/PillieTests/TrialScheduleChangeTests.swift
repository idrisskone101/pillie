//
//  TrialScheduleChangeTests.swift
//  PillieTests
//
//  A pack, regimen, or method change during a Reverse Trial (ADR 0007): days
//  already lived keep the classification they had when lived, so break days
//  lived under the old pack never consume trial days, and only days from the
//  change on follow the new pack.
//

import XCTest

@testable import Pillie

@MainActor
final class TrialScheduleChangeTests: XCTestCase {

    // Bare SwiftData models can deallocate inside the hosted XCTest
    // invocation on the Xcode 27 beta. Keep the packs for the process.
    private static var retainedPacks: [PillPack] = []

    override func setUp() {
        super.setUp()
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
    }

    override func tearDown() {
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.updateActiveDaySchedule(.everyCalendarDay)
        super.tearDown()
    }

    func testSwitchToEveryDayAfterABreakKeepsTheLivedBreakUncounted() {
        // 21/7 from Sep 10: the Sep 30 grant is pill 21, Oct 1-7 are the sugar
        // week, Oct 8-21 the 14 counted days. On Oct 15 the user switches to
        // Every day: Oct 8-14 are 7 lived active days, Oct 15-21 the other 7.
        let manager = SubscriptionManager.shared
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(9, 10)), now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12))

        let switchMoment = local(10, 15, 12)
        manager.updateActiveDaySchedule(pack: pack(.everyDay, from: local(10, 15)), now: switchMoment)

        XCTAssertTrue(manager.hasPlusAccess)
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 22, 0)
        )
        XCTAssertEqual(
            TrialStatusPresentation.make(
                state: manager.plusAccessState,
                calendar: .current,
                now: switchMoment
            )?.daysRemaining,
            7
        )
    }

    func testSwitchToABreakRegimenDoesNotHandOutLivedDaysAgain() {
        // Every day, grant Oct 1: Oct 2-13 are 12 lived active days. A 21/7
        // pack started Oct 14 counts Oct 14 and 15, so the trial ends Oct 16.
        let manager = SubscriptionManager.shared
        manager.updateActiveDaySchedule(pack: pack(.everyDay, from: local(9, 1)), now: local(10, 1, 12))
        manager.grantReverseTrial(now: local(10, 1, 12))

        let switchMoment = local(10, 14, 12)
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(10, 14)), now: switchMoment)

        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 16, 0)
        )
        XCTAssertEqual(
            TrialStatusPresentation.make(
                state: manager.plusAccessState,
                calendar: .current,
                now: switchMoment
            )?.daysRemaining,
            2
        )
    }

    func testLivedDaysSurviveARelaunch() {
        // Same switch as above, then the app relaunches: it reloads trial state
        // from the grant store and pushes the current (Every day) pack again.
        let store = InMemoryTrialGrantStore()
        let manager = SubscriptionManager.shared
        manager.setTrialGrantStoreForTesting(store)
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(9, 10)), now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12))
        let everyDay = pack(.everyDay, from: local(10, 15))
        manager.updateActiveDaySchedule(pack: everyDay, now: local(10, 15, 12))

        manager.setTrialGrantStoreForTesting(store)
        manager.updateActiveDaySchedule(pack: everyDay, now: local(10, 16, 9))

        XCTAssertTrue(manager.hasPlusAccess)
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 22, 0)
        )
    }

    // MARK: - Helpers

    private func pack(_ regimen: PillPack.PillRegimenPreset, from startDate: Date) -> PillPack {
        let pack = PillPack(
            method: .pill,
            pillRegimen: regimen,
            startDate: startDate,
            packNumber: 1,
            isCurrent: true
        )
        Self.retainedPacks.append(pack)
        return pack
    }

    /// An instant in `Calendar.current`, the calendar the trial clock reads.
    private func local(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}
