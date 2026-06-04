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
        XCTAssertEqual(content.title, "Backup for chaotic days")
        XCTAssertEqual(content.benefits.map(\.title), [
            "Block the scroll",
            "Shake to make it count"
        ])
        XCTAssertEqual(content.freeTierMessage, "Free daily + smart reminders and tracking stay yours.")
        XCTAssertEqual(content.primaryCTA, "Try Plus Free")
        XCTAssertEqual(content.freeCTA, "Continue for Free")

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleCopy.contains("limited offer"))
        XCTAssertFalse(visibleCopy.contains("habit mastery"))
        XCTAssertFalse(visibleCopy.contains("google pay"))
        XCTAssertFalse(visibleCopy.contains("credit card"))
        XCTAssertFalse(visibleCopy.contains("no ads"))
    }
}
