//
//  SubscriptionManagerEdgeCaseTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class SubscriptionManagerEdgeCaseTests: XCTestCase {
    override func tearDown() {
        SubscriptionManager.shared.setPlusForTesting(false)
        super.tearDown()
    }

    func testDebugPlusOverrideCanExerciseEntitlementGatedFlows() {
        SubscriptionManager.shared.setPlusForTesting(false)
        XCTAssertFalse(SubscriptionManager.shared.isPlus)

        SubscriptionManager.shared.setPlusForTesting(true)
        XCTAssertTrue(SubscriptionManager.shared.isPlus)

        SubscriptionManager.shared.setPlusForTesting(false)
        XCTAssertFalse(SubscriptionManager.shared.isPlus)
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
        XCTAssertTrue(SubscriptionManager.shared.isPlus)
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
        XCTAssertFalse(SubscriptionManager.shared.isPlus)
    }

    func testSuccessfulPurchaseActivatesPlus() throws {
        SubscriptionManager.shared.setPlusForTesting(false)

        try SubscriptionManager.shared.applyPurchaseResult(
            userCancelled: false,
            isPlusEntitlementActive: true
        )

        XCTAssertTrue(SubscriptionManager.shared.isPlus)
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
