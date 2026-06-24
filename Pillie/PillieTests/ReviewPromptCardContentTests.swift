//
//  ReviewPromptCardContentTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the Sentiment Gate
//  card content factory (PRD #132 / ADR 0005). Mirrors
//  AdaptiveReminderSuggestionCardContentTests.
//

import XCTest

@testable import Pillie

final class ReviewPromptCardContentTests: XCTestCase {

    // MARK: - Decision gate (AC2)

    func testReturnsNilForEverySuppressedReason() {
        let reasons: [ReviewPromptEligibility.Decision.Reason] = [
            .ineligibleStreak,
            .permanentlySuppressed,
            .inCooldown,
            .lifetimeCapReached,
            .yieldingToOtherCard
        ]
        for reason in reasons {
            XCTAssertNil(
                ReviewPromptCardContent.make(decision: .suppressed(reason)),
                "expected nil content for \(reason)"
            )
        }
    }

    func testBuildsContentWhenDecisionIsShow() {
        XCTAssertNotNil(ReviewPromptCardContent.make(decision: .show))
    }

    // MARK: - Static, method-agnostic copy

    func testCopyIsStaticAndAsksSentimentFirstWithBothChoices() {
        let content = ReviewPromptCardContent.make(decision: .show)
        XCTAssertEqual(content?.headline, "Enjoying Pillie?")
        XCTAssertFalse(content?.body.isEmpty ?? true)
        XCTAssertFalse(content?.positiveTitle.isEmpty ?? true)
        XCTAssertFalse(content?.negativeTitle.isEmpty ?? true)
        XCTAssertNotEqual(content?.positiveTitle, content?.negativeTitle)
    }

    func testCopyIsTheStaticMethodAgnosticStrings() {
        // Pinning the exact strings proves the copy is static — it is not assembled from
        // the method or Streak the eligibility check used.
        let content = ReviewPromptCardContent.make(decision: .show)
        XCTAssertEqual(content?.headline, "Enjoying Pillie?")
        XCTAssertEqual(content?.body, "We'd love to hear how it's going for you.")
        XCTAssertEqual(content?.positiveTitle, "Yes, I'm enjoying it")
        XCTAssertEqual(content?.negativeTitle, "Not really")
    }

    func testCopyNeverInterpolatesStreakDigitsOrMethod() {
        // The factory takes only a `decision` (no method/Streak input), so the copy is
        // method-agnostic by construction; additionally guard that no Streak value can
        // leak as a digit, and no method name appears. ("pill" is excluded — it is a
        // substring of the brand name "Pillie".)
        let content = ReviewPromptCardContent.make(decision: .show)
        let allText = (content?.visibleCopy ?? []).joined(separator: " ")
        XCTAssertNil(allText.rangeOfCharacter(from: .decimalDigits), "Copy leaked a digit: \(allText)")
        let lower = allText.lowercased()
        for leak in ["patch", "ring", "streak"] {
            XCTAssertFalse(lower.contains(leak), "copy must not leak '\(leak)': \(allText)")
        }
    }
}
