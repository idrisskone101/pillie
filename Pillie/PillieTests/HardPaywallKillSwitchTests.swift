//
//  HardPaywallKillSwitchTests.swift
//  PillieTests
//
//  The RevenueCat kill switch (ADR 0008): `hard_paywall_enabled = false`
//  restores legacy terms, which keep free daily reminders. The flag can
//  resolve after the cold-launch reminder replan, so a flip of the resolved
//  terms must replan the way an access change does, once per flip.
//

import XCTest

@testable import Pillie

@MainActor
final class HardPaywallKillSwitchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(true)
    }

    override func tearDown() {
        SubscriptionManager.shared.onEntitlementChange = nil
        SubscriptionManager.shared.debugSetHardPaywallEnabled(true)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(nil)
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
        SubscriptionManager.shared.setPlusForTesting(false)
        super.tearDown()
    }

    func testARollbackReplansOncePerFlipOfTheTerms() {
        let manager = SubscriptionManager.shared
        manager.grantReverseTrial(now: Date(), termsCohort: .postCutover)
        var replans = 0
        manager.onEntitlementChange = { _ in replans += 1 }

        // The dashboard rollback lands after launch, then a later fetch confirms it.
        manager.debugSetHardPaywallEnabled(false)
        manager.debugSetHardPaywallEnabled(false)

        XCTAssertEqual(manager.trialEndTerms, .legacy)
        XCTAssertEqual(replans, 1)

        manager.debugSetHardPaywallEnabled(true)

        XCTAssertEqual(manager.trialEndTerms, .hardPaywall)
        XCTAssertEqual(replans, 2)
    }

    func testAFlagFlipThatLeavesTheTermsAloneDoesNotReplan() {
        // Grandfathered terms are legacy either way.
        let manager = SubscriptionManager.shared
        manager.grantReverseTrial(now: Date(), termsCohort: .preCutover)
        var replans = 0
        manager.onEntitlementChange = { _ in replans += 1 }

        manager.debugSetHardPaywallEnabled(false)

        XCTAssertEqual(manager.trialEndTerms, .legacy)
        XCTAssertEqual(replans, 0)
    }
}
