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
    // invocation on the Xcode 27 beta. Keep the packs and stores for the process.
    private static var retainedPacks: [PillPack] = []
    private static var retainedFixtures: [InMemoryStoreFixture] = []
    private var originalZone: TimeZone!

    override func setUp() {
        super.setUp()
        originalZone = NSTimeZone.default
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
    }

    override func tearDown() {
        NSTimeZone.default = originalZone
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(true)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(nil)
        InMemoryStoreFactory.resetClockAndDefaults()
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

    func testRemindersAndTrialNoticesKeepTheBadgesExpiry() throws {
        // Hard-paywall terms: reminders stop at the trial's end. After the Oct 15
        // switch the trial still ends Oct 22, so the week's reminders stay and
        // the notices land 5 and 2 days before it and on its morning.
        let manager = SubscriptionManager.shared
        manager.debugSetHardPaywallEnabled(true)
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(9, 10)), now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12), termsCohort: .postCutover)
        let switchMoment = local(10, 15, 12)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: switchMoment,
            regimen: .everyDay,
            startDate: local(10, 15)
        )
        Self.retainedFixtures.append(fixture)
        manager.updateActiveDaySchedule(pack: fixture.store.activePack, now: switchMoment)

        let requests = KeptNotificationManager.make(hasBlockerSetup: { false })
            .managedRequestSummariesForTesting(store: fixture.store, now: switchMoment)

        let baseDays = requests
            .filter { $0.requestKind == ReminderSchedulePlanner.DueReminderKind.base.rawValue }
            .compactMap { $0.fireDate.map(Calendar.current.startOfDay(for:)) }
            .sorted()
        XCTAssertEqual(baseDays, (15...21).map { local(10, $0) })
        let notices = requests
            .filter { $0.requestKind == "trialExpiryWarning" }
            .compactMap(\.fireDate)
            .sorted()
        XCTAssertEqual(notices, [local(10, 17, 20), local(10, 20, 20), local(10, 22, 10)])
    }

    func testAReinstallBeforeOnboardingKeepsTheSavedRhythm() {
        // A reinstall keeps the Keychain grant and its ledger but wipes the pack.
        // Launch pushes no pack on Oct 3; onboarding rebuilds the same 21/7 pack
        // on Oct 5. The sugar week still never counts, so the trial ends Oct 22.
        let store = InMemoryTrialGrantStore()
        let manager = SubscriptionManager.shared
        manager.setTrialGrantStoreForTesting(store)
        let twentyOneSeven = pack(.twentyOneSeven, from: local(9, 10))
        manager.updateActiveDaySchedule(pack: twentyOneSeven, now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12))

        manager.setTrialGrantStoreForTesting(store)
        manager.updateActiveDaySchedule(pack: nil, now: local(10, 3, 9))
        manager.updateActiveDaySchedule(pack: twentyOneSeven, now: local(10, 5, 9))

        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 22, 0)
        )
    }

    func testAChangeAfterTheTrialEndedKeepsItsEnd() {
        // The 21/7 trial above ended Oct 22. A grandfathered user who switches
        // to Every day on Oct 25 must not see the end date move to Oct 15.
        let manager = SubscriptionManager.shared
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(9, 10)), now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12))

        manager.updateActiveDaySchedule(pack: pack(.everyDay, from: local(10, 25)), now: local(10, 25, 12))

        XCTAssertFalse(manager.hasPlusAccess)
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 22, 0)
        )
    }

    func testLivedDaysStayOnTheirDatesAcrossATimeZoneChange() {
        // The Oct 15 switch happens in Paris; the user then flies to New York.
        // The days lived before Oct 15 stay 7, and Oct 15 stays the switch day.
        NSTimeZone.default = TimeZone(identifier: "Europe/Paris")!
        let manager = SubscriptionManager.shared
        manager.updateActiveDaySchedule(pack: pack(.twentyOneSeven, from: local(9, 10)), now: local(9, 30, 12))
        manager.grantReverseTrial(now: local(9, 30, 12))
        let everyDay = pack(.everyDay, from: local(10, 15))
        manager.updateActiveDaySchedule(pack: everyDay, now: local(10, 15, 12))

        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        // Read before anything pushes the pack in the new zone, then after.
        XCTAssertEqual(
            PlusAccessMirror.validUntil(state: manager.plusAccessState, calendar: .current),
            local(10, 22, 0)
        )
        manager.updateActiveDaySchedule(pack: everyDay, now: local(10, 16, 9))

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
