//
//  ReviewPromptCardContentTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the Sentiment Gate
//  card content factory (#133). Mirrors AdaptiveReminderSuggestionCardContentTests.
//

import XCTest

@testable import Pillie

final class ReviewPromptCardContentTests: XCTestCase {

    // MARK: - Decision gate (AC2)

    func testReturnsNilUnlessDecisionIsShow() {
        XCTAssertNil(ReviewPromptCardContent.make(decision: .hide))
    }

    func testBuildsContentWhenDecisionIsShow() {
        let content = ReviewPromptCardContent.make(decision: .show)
        XCTAssertNotNil(content)
    }

    // MARK: - Static, method-agnostic copy

    func testCopyIsStaticAndAsksSentimentFirst() {
        let content = ReviewPromptCardContent.make(decision: .show)
        XCTAssertEqual(content?.headline, "Enjoying Pillie?")
        XCTAssertFalse(content?.body.isEmpty ?? true)
        XCTAssertFalse(content?.positiveTitle.isEmpty ?? true)
    }

    func testCopyNeverInterpolatesStreakDigits() {
        // The factory takes only a `decision` (no method/Streak input), so the copy is
        // method-agnostic by construction; here we additionally guard that no Streak
        // value can leak as a digit in the rendered strings.
        let content = ReviewPromptCardContent.make(decision: .show)
        let allText = [content?.headline, content?.body, content?.positiveTitle]
            .compactMap { $0 }
            .joined(separator: " ")
        XCTAssertNil(allText.rangeOfCharacter(from: .decimalDigits), "Copy leaked a digit: \(allText)")
    }

    func testCopyIsTheStaticMethodAgnosticStrings() {
        // Pinning the exact strings proves the copy is static — it is not assembled from
        // the method or Streak the eligibility check used.
        let content = ReviewPromptCardContent.make(decision: .show)
        XCTAssertEqual(content?.headline, "Enjoying Pillie?")
        XCTAssertEqual(content?.body, "We'd love to hear how it's going for you.")
        XCTAssertEqual(content?.positiveTitle, "Yes, I'm enjoying it")
    }
}
