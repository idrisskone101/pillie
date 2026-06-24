//
//  ReviewPromptEligibilityTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for Review Prompt
//  Eligibility — the pure Sentiment Gate gating seam (PRD #132 / ADR 0005).
//  Mirrors ProtectionPlanCompletionTests.
//

import XCTest

@testable import Pillie

final class ReviewPromptEligibilityTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func state(
        method: ContraceptiveMethod,
        streak: Int,
        suppressed: Bool = false,
        lastSoftDismissal: Date? = nil,
        softDismissalCount: Int = 0,
        higherPriorityCardShowing: Bool = false
    ) -> ReviewPromptEligibility.State {
        ReviewPromptEligibility.State(
            method: method,
            currentStreak: streak,
            permanentlySuppressed: suppressed,
            lastSoftDismissal: lastSoftDismissal,
            softDismissalCount: softDismissalCount,
            higherPriorityCardShowing: higherPriorityCardShowing,
            now: now
        )
    }

    // MARK: - Method-aware thresholds (AC1–3, AC12)

    func testPillShowsAtThreeAndIsIneligibleBelow() {
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 2)),
                       .suppressed(.ineligibleStreak))
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 3)), .show)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 9)), .show)
    }

    func testPatchShowsAtOneAndIsIneligibleBelow() {
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .patch, streak: 0)),
                       .suppressed(.ineligibleStreak))
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .patch, streak: 1)), .show)
    }

    func testRingShowsAtTwoAndIsIneligibleBelow() {
        // Ring is >= 2 (not >= 1) so the day-one ring insertion does not fire at setup.
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 1)),
                       .suppressed(.ineligibleStreak))
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 2)), .show)
    }

    func testRingDayOneInsertionStaysSuppressed() {
        // The single day-one insertion produces a streak of 1; it must not qualify.
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .ring, streak: 1)),
                       .suppressed(.ineligibleStreak))
    }

    func testBrokenStreakQuietlySuppresses() {
        // AC12: a streak that drops back below threshold makes the card disappear.
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: state(method: .pill, streak: 0)),
                       .suppressed(.ineligibleStreak))
    }

    func testThresholdsAreMethodAware() {
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .pill), 3)
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .patch), 1)
        XCTAssertEqual(ReviewPromptEligibility.threshold(for: .ring), 2)
    }

    // MARK: - Permanent suppression after a response (AC9)

    func testPermanentSuppressionHidesEvenWhenOtherwiseEligible() {
        for method in ContraceptiveMethod.allCases {
            let threshold = ReviewPromptEligibility.threshold(for: method)
            XCTAssertEqual(
                ReviewPromptEligibility.evaluate(
                    for: state(method: method, streak: threshold + 5, suppressed: true)
                ),
                .suppressed(.permanentlySuppressed),
                "\(method) must stay hidden once permanently suppressed."
            )
        }
    }

    func testPermanentSuppressionOutranksEveryOtherCondition() {
        let answered = state(
            method: .ring,
            streak: 9,
            suppressed: true,
            lastSoftDismissal: now,
            softDismissalCount: 3,
            higherPriorityCardShowing: true
        )
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: answered),
                       .suppressed(.permanentlySuppressed))
    }

    // MARK: - 90-day soft-dismissal cooldown (AC8, AC17)

    func testWithinCooldownSuppresses() {
        let eightyNineDaysAgo = now.addingTimeInterval(-89 * 86_400)
        let inCooldown = state(method: .pill, streak: 5, lastSoftDismissal: eightyNineDaysAgo, softDismissalCount: 1)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: inCooldown), .suppressed(.inCooldown))
    }

    func testCooldownEndsExactlyAtNinetyDays() {
        let ninetyDaysAgo = now.addingTimeInterval(-90 * 86_400)
        let afterCooldown = state(method: .pill, streak: 5, lastSoftDismissal: ninetyDaysAgo, softDismissalCount: 1)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: afterCooldown), .show)
    }

    func testCooldownBoundaryHelperIsHalfOpen() {
        let dismissal = now.addingTimeInterval(-90 * 86_400)
        XCTAssertFalse(ReviewPromptEligibility.isWithinCooldown(lastSoftDismissal: dismissal, now: now))
        let justInside = now.addingTimeInterval(-(90 * 86_400 - 1))
        XCTAssertTrue(ReviewPromptEligibility.isWithinCooldown(lastSoftDismissal: justInside, now: now))
    }

    // MARK: - 3-appearance lifetime cap (AC8)

    func testSecondDismissalStillReshowsAfterCooldown() {
        let longAgo = now.addingTimeInterval(-200 * 86_400)
        let twiceDismissed = state(method: .pill, streak: 5, lastSoftDismissal: longAgo, softDismissalCount: 2)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: twiceDismissed), .show)
    }

    func testThirdDismissalReachesLifetimeCap() {
        let longAgo = now.addingTimeInterval(-200 * 86_400)
        let capped = state(method: .pill, streak: 5, lastSoftDismissal: longAgo, softDismissalCount: 3)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: capped), .suppressed(.lifetimeCapReached))
        XCTAssertEqual(ReviewPromptEligibility.softDismissalLifetimeCap, 3)
    }

    // MARK: - Yielding to a higher-priority card (AC10, AC11)

    func testYieldsWhenAHigherPriorityCardIsShowing() {
        let yielding = state(method: .pill, streak: 5, higherPriorityCardShowing: true)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: yielding),
                       .suppressed(.yieldingToOtherCard))
    }

    func testShowsWhenEligibleAndNoHigherPriorityCard() {
        let eligible = state(method: .pill, streak: 5, higherPriorityCardShowing: false)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: eligible), .show)
    }

    func testIneligibleStreakOutranksTheYieldReason() {
        let bothFail = state(method: .pill, streak: 1, higherPriorityCardShowing: true)
        XCTAssertEqual(ReviewPromptEligibility.evaluate(for: bothFail),
                       .suppressed(.ineligibleStreak))
    }

    // MARK: - Equatable

    func testDecisionIsEquatable() {
        XCTAssertEqual(ReviewPromptEligibility.Decision.show, .show)
        XCTAssertNotEqual(ReviewPromptEligibility.Decision.show, .suppressed(.ineligibleStreak))
        XCTAssertNotEqual(
            ReviewPromptEligibility.Decision.suppressed(.inCooldown),
            .suppressed(.lifetimeCapReached)
        )
    }
}
