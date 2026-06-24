//
//  ReviewPromptEligibilityTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for Review Prompt
//  Eligibility — the pure Sentiment Gate gating seam (PRD #132 / ADR 0005 / #133).
//  Mirrors ProtectionPlanCompletionTests.
//

import XCTest

@testable import Pillie

final class ReviewPromptEligibilityTests: XCTestCase {

    private func state(
        method: ContraceptiveMethod,
        streak: Int,
        suppressed: Bool = false
    ) -> ReviewPromptEligibility.State {
        ReviewPromptEligibility.State(
            method: method,
            currentStreak: streak,
            permanentlySuppressed: suppressed
        )
    }

    // MARK: - Method-aware thresholds (AC1)

    func testPillShowsAtThreeAndHidesBelow() {
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 2)), .hide)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 3)), .show)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 9)), .show)
    }

    func testPatchShowsAtOneAndHidesBelow() {
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .patch, streak: 0)), .hide)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .patch, streak: 1)), .show)
    }

    func testRingShowsAtTwoAndHidesBelow() {
        // Ring is >= 2 (not >= 1) so the day-one ring insertion does not fire at setup.
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 1)), .hide)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 2)), .show)
    }

    func testRingDayOneInsertionStaysSuppressed() {
        // The single day-one insertion produces a streak of 1; it must not qualify.
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 1)), .hide)
    }

    // MARK: - Permanent suppression (AC4)

    func testPermanentSuppressionHidesEvenWhenOtherwiseEligible() {
        for method in ContraceptiveMethod.allCases {
            let threshold = ReviewPromptEligibility.threshold(for: method)
            XCTAssertEqual(
                ReviewPromptEligibility.evaluate(
                    for: state(method: method, streak: threshold + 5, suppressed: true)
                ),
                .hide,
                "\(method) must stay hidden once permanently suppressed."
            )
        }
    }

    // MARK: - Threshold table

    func testThresholdsAreMethodAware() {
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .pill), 3)
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .patch), 1)
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .ring), 2)
    }

    func testDecisionIsEquatable() {
        XCTAssertEqual(ReviewPromptEligibility.Decision.show, .show)
        XCTAssertNotEqual(ReviewPromptEligibility.Decision.show, .hide)
    }
}
