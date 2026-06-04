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
        XCTAssertEqual(content.title, "Choose")
        XCTAssertEqual(content.titleAccent, "Pillie Plus")
        XCTAssertEqual(content.subtitle, "App blocks and shake checks when reminders need backup.")
        XCTAssertEqual(content.benefits.map(\.title), [
            "Block the scroll",
            "Shake to make it count"
        ])
        XCTAssertEqual(content.primaryCTA, "Try Pillie Plus for free")
        XCTAssertEqual(content.monthlyCTA, "Start Pillie Plus monthly")
        XCTAssertEqual(content.freeCTA, "Continue for Free")

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleCopy.contains("limited offer"))
        XCTAssertFalse(visibleCopy.contains("habit mastery"))
        XCTAssertFalse(visibleCopy.contains("google pay"))
        XCTAssertFalse(visibleCopy.contains("credit card"))
        XCTAssertFalse(visibleCopy.contains("no ads"))
        XCTAssertFalse(content.primaryCTA.contains("Try Plus"))
        XCTAssertFalse(content.monthlyCTA.contains("Go Monthly"))
    }
}
