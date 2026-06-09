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
}
