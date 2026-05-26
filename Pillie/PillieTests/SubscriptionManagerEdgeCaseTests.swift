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
}
