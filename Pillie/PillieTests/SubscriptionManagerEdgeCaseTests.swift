//
//  SubscriptionManagerEdgeCaseTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class SubscriptionManagerEdgeCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Isolate from any real Keychain trial grant: these tests assert that
        // the hook mirrors the entitlement, which only holds with no trial.
        SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
    }

    override func tearDown() {
        SubscriptionManager.shared.onEntitlementChange = nil
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.onEntitlementChange = nil
        super.tearDown()
    }

    func testEntitlementChangeFiresRescheduleHookOnUpgradeAndChurn() throws {
        SubscriptionManager.shared.setPlusForTesting(false)

        var observed: [Bool] = []
        SubscriptionManager.shared.onEntitlementChange = { observed.append($0) }

        // Upgrade.
        try SubscriptionManager.shared.applyPurchaseResult(
            userCancelled: false,
            isPlusEntitlementActive: true
        )
        // Churn.
        SubscriptionManager.shared.setPlusForTesting(false)

        XCTAssertEqual(observed, [true, false])
    }

    func testEntitlementHookDoesNotFireWhenStateIsUnchanged() {
        SubscriptionManager.shared.setPlusForTesting(true)

        var fireCount = 0
        SubscriptionManager.shared.onEntitlementChange = { _ in fireCount += 1 }

        SubscriptionManager.shared.setPlusForTesting(true)

        XCTAssertEqual(fireCount, 0)
    }

    func testDebugPlusOverrideCanExerciseEntitlementGatedFlows() {
        SubscriptionManager.shared.setPlusForTesting(false)
        XCTAssertFalse(SubscriptionManager.shared.hasEntitlement)

        SubscriptionManager.shared.setPlusForTesting(true)
        XCTAssertTrue(SubscriptionManager.shared.hasEntitlement)

        SubscriptionManager.shared.setPlusForTesting(false)
        XCTAssertFalse(SubscriptionManager.shared.hasEntitlement)
    }

    func testCancelledPurchaseDoesNotChangePlusState() {
        SubscriptionManager.shared.setPlusForTesting(true)

        XCTAssertThrowsError(
            try SubscriptionManager.shared.applyPurchaseResult(
                userCancelled: true,
                isPlusEntitlementActive: false
            )
        ) { error in
            XCTAssertEqual(error as? SubscriptionPurchaseError, .userCancelled)
        }
        XCTAssertTrue(SubscriptionManager.shared.hasEntitlement)
    }

    func testPurchaseWithoutPlusEntitlementDoesNotActivatePlus() {
        SubscriptionManager.shared.setPlusForTesting(false)

        XCTAssertThrowsError(
            try SubscriptionManager.shared.applyPurchaseResult(
                userCancelled: false,
                isPlusEntitlementActive: false
            )
        ) { error in
            XCTAssertEqual(error as? SubscriptionPurchaseError, .missingPlusEntitlement)
        }
        XCTAssertFalse(SubscriptionManager.shared.hasEntitlement)
    }

    func testSuccessfulPurchaseActivatesPlus() throws {
        SubscriptionManager.shared.setPlusForTesting(false)

        try SubscriptionManager.shared.applyPurchaseResult(
            userCancelled: false,
            isPlusEntitlementActive: true
        )

        XCTAssertTrue(SubscriptionManager.shared.hasEntitlement)
    }

    func testPurchaseOutcomeDistinguishesTrialPaidAndExcludesSandbox() {
        // A real immediate charge → purchase_completed.
        XCTAssertEqual(
            PurchaseOutcome(isTrial: false, isSandbox: false).conversionEvent,
            .purchaseCompleted
        )
        // A free trial start → its own distinct funnel step.
        XCTAssertEqual(
            PurchaseOutcome(isTrial: true, isSandbox: false).conversionEvent,
            .trialStarted
        )
        // Sandbox transactions (dev/TestFlight/review) are never real conversions and
        // must emit nothing, so they don't inflate paid metrics.
        XCTAssertNil(PurchaseOutcome(isTrial: true, isSandbox: true).conversionEvent)
        XCTAssertNil(PurchaseOutcome(isTrial: false, isSandbox: true).conversionEvent)
    }
}
