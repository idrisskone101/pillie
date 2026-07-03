//
//  SubscriptionManagerTrialTests.swift
//  PillieTests
//
//  Reverse Trial integration at the SubscriptionManager choke point
//  (issue #160): grant and expiry must fire the same entitlement-change hook
//  a purchase does, so Smart Reminders reschedule and blocking reconciles
//  with no new plumbing. Mirrors SubscriptionManagerEdgeCaseTests.
//

import XCTest

@testable import Pillie

@MainActor
final class SubscriptionManagerTrialTests: XCTestCase {

    private let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
    }

    override func tearDown() {
        SubscriptionManager.shared.onEntitlementChange = nil
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.onEntitlementChange = nil
        super.tearDown()
    }

    func testTrialGrantFiresEntitlementChangeHookAndUnlocksPlusAccess() {
        var observed: [Bool] = []
        SubscriptionManager.shared.onEntitlementChange = { observed.append($0) }

        SubscriptionManager.shared.grantReverseTrial()

        XCTAssertEqual(observed, [true])
        XCTAssertTrue(SubscriptionManager.shared.hasPlusAccess)
        XCTAssertFalse(SubscriptionManager.shared.hasEntitlement)
    }

    func testTrialExpiryFiresEntitlementChangeHookAndGatesOff() {
        let grantMoment = Date(timeIntervalSince1970: 1_750_000_000)
        SubscriptionManager.shared.grantReverseTrial(now: grantMoment)

        var observed: [Bool] = []
        SubscriptionManager.shared.onEntitlementChange = { observed.append($0) }

        // Re-evaluating while still inside the trial is a no-op…
        SubscriptionManager.shared.refreshPlusAccess(now: grantMoment)
        XCTAssertEqual(observed, [])

        // …but crossing the day-14 rollover flips access off exactly once.
        let wellPastExpiry = calendar.date(byAdding: .day, value: 20, to: grantMoment)!
        SubscriptionManager.shared.refreshPlusAccess(now: wellPastExpiry)
        SubscriptionManager.shared.refreshPlusAccess(now: wellPastExpiry)

        XCTAssertEqual(observed, [false])
        XCTAssertFalse(SubscriptionManager.shared.hasPlusAccess)
    }

    func testGrantIsIdempotentAndKeepsTheOriginalClock() {
        let firstGrant = Date(timeIntervalSince1970: 1_750_000_000)
        SubscriptionManager.shared.grantReverseTrial(now: firstGrant)

        // A second grant must not restart the 14-day clock.
        let muchLater = calendar.date(byAdding: .day, value: 30, to: firstGrant)!
        SubscriptionManager.shared.grantReverseTrial(now: muchLater)

        XCTAssertEqual(SubscriptionManager.shared.trialGrantDate, firstGrant)
    }

    func testGrantReportsWhetherANewGrantWasWritten() {
        // The Trial Granted Moment fires `trial_granted` iff the grant was actually
        // written on this showing — revisiting the screen (Back, relaunch) must not
        // re-emit the event (issue #164).
        let firstGrant = Date(timeIntervalSince1970: 1_750_000_000)
        XCTAssertTrue(SubscriptionManager.shared.grantReverseTrial(now: firstGrant))

        let revisit = calendar.date(byAdding: .day, value: 1, to: firstGrant)!
        XCTAssertFalse(SubscriptionManager.shared.grantReverseTrial(now: revisit))
    }

    func testGrantWhileEntitledDoesNotFireHook() {
        SubscriptionManager.shared.setPlusForTesting(true)

        var fireCount = 0
        SubscriptionManager.shared.onEntitlementChange = { _ in fireCount += 1 }

        SubscriptionManager.shared.grantReverseTrial()

        XCTAssertEqual(fireCount, 0)
        XCTAssertTrue(SubscriptionManager.shared.hasPlusAccess)
    }

    func testEntitlementWritesMarkEntitlementResolved() {
        // The existing-user update grant (#165) must not decide before RevenueCat
        // state has loaded — any write through the entitlement funnel (purchase,
        // restore, refresh, delegate push) marks it resolved.
        SubscriptionManager.shared.setPlusForTesting(false)
        XCTAssertTrue(SubscriptionManager.shared.hasResolvedEntitlement)
    }

    func testEntitlementChurnDuringActiveTrialKeepsAccessWithoutFiring() {
        // Subscriber with an active trial grant on record: losing the
        // entitlement must not interrupt Plus Access while the trial covers it.
        SubscriptionManager.shared.grantReverseTrial()
        SubscriptionManager.shared.setPlusForTesting(true)

        var fireCount = 0
        SubscriptionManager.shared.onEntitlementChange = { _ in fireCount += 1 }

        SubscriptionManager.shared.setPlusForTesting(false)

        XCTAssertEqual(fireCount, 0)
        XCTAssertTrue(SubscriptionManager.shared.hasPlusAccess)
    }
}
