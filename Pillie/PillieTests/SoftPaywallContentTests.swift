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
        XCTAssertEqual(content.title, "Consistency with Plus")
        XCTAssertEqual(content.benefits.map(\.title), [
            "Strict App Blocking",
            "Shake to Confirm"
        ])
        XCTAssertEqual(content.freeTierMessage, "Free reminders and tracking stay included.")
        XCTAssertEqual(content.primaryCTA, "Start 7-Day Free Trial")
        XCTAssertEqual(content.freeCTA, "Continue for Free")

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleCopy.contains("limited offer"))
        XCTAssertFalse(visibleCopy.contains("habit mastery"))
        XCTAssertFalse(visibleCopy.contains("google pay"))
        XCTAssertFalse(visibleCopy.contains("credit card"))
        XCTAssertFalse(visibleCopy.contains("no ads"))
    }
}
