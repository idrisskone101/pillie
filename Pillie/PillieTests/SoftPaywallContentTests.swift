//
//  SoftPaywallContentTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class SoftPaywallContentTests: XCTestCase {
    func testSoftPaywallContentUsesTruthfulPlusBenefitsAndKeepsFreePathClear() {
        let content = SoftPaywallContent.default

        XCTAssertEqual(content.badge, "Pillie Plus")
        XCTAssertEqual(content.title, "Stay on Track with")
        XCTAssertEqual(content.titleAccent, "Pillie Plus")
        XCTAssertEqual(content.subtitle, "App blocks and shake checks when reminders need backup.")
        XCTAssertEqual(content.benefits.map(\.title), [
            "Block the scroll",
            "Shake to make it count",
            "More Plus perks coming"
        ])
        XCTAssertEqual(content.benefits.last?.subtitle, "New Pillie Plus tools are included as they launch.")
        XCTAssertEqual(content.primaryCTA, "Try Pillie Plus for free")
        XCTAssertEqual(content.monthlyCTA, "Start Pillie Plus monthly")
        XCTAssertEqual(content.freeCTA, "Continue with free plan")

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleCopy.contains("limited offer"))
        XCTAssertFalse(visibleCopy.contains("habit mastery"))
        XCTAssertFalse(visibleCopy.contains("google pay"))
        XCTAssertFalse(visibleCopy.contains("credit card"))
        XCTAssertFalse(visibleCopy.contains("no ads"))
        XCTAssertFalse(content.primaryCTA.contains("Try Plus"))
        XCTAssertFalse(content.monthlyCTA.contains("Go Monthly"))
    }

    func testFreePlanConfirmationContentConfirmsFreeFeaturesWithoutAnotherUpgradeAsk() {
        let content = FreePlanConfirmationContent.default

        XCTAssertEqual(content.title, "You're all set with")
        XCTAssertEqual(content.titleAccent, "Pillie")
        XCTAssertEqual(content.primaryCTA, "Start Using Pillie")
        XCTAssertEqual(content.confirmations.map(\.title), [
            "Daily reminders",
            "Smart reminders",
            "Cycle tracking"
        ])

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertTrue(visibleCopy.contains("active"))
        XCTAssertTrue(visibleCopy.contains("tracking"))
        XCTAssertFalse(visibleCopy.contains("app blocking"))
        XCTAssertFalse(visibleCopy.contains("screen time"))
        XCTAssertFalse(visibleCopy.contains("upgrade"))
        XCTAssertFalse(visibleCopy.contains("pillie plus"))
        XCTAssertFalse(visibleCopy.contains("limited offer"))
    }
}
