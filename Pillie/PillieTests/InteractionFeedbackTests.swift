//
//  InteractionFeedbackTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class InteractionFeedbackTests: XCTestCase {
    func testSemanticTabChangeFeedbackUsesSelectionIntent() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)

        feedback.perform(.tabChange)
        XCTAssertEqual(feedbackRecorder.performedIntents, [.tabChange])
    }

    func testSharedMotionSemanticsIncludeCalmerReducedAndConstrainedProfiles() {
        XCTAssertEqual(
            PillieMotion.Semantic.allCases,
            [.quick, .standard, .entrance, .commitSpring, .rewardSpring]
        )

        XCTAssertEqual(PillieMotion.profile(for: .quick).duration, 0.16)
        XCTAssertEqual(PillieMotion.profile(for: .standard).duration, 0.25)
        XCTAssertEqual(PillieMotion.profile(for: .entrance).duration, 0.5)
        XCTAssertEqual(PillieMotion.profile(for: .commitSpring).curve, .spring)
        XCTAssertEqual(PillieMotion.profile(for: .rewardSpring).curve, .spring)

        let reducedMotion = PillieMotion.profile(
            for: .standard,
            accessibilityReduceMotion: true,
            performanceTier: .standard
        )
        let constrained = PillieMotion.profile(
            for: .rewardSpring,
            accessibilityReduceMotion: false,
            performanceTier: .constrained
        )

        XCTAssertEqual(reducedMotion.curve, .easeInOut)
        XCTAssertTrue(reducedMotion.usesCalmerSpatialMotion)
        XCTAssertEqual(constrained.curve, .easeInOut)
        XCTAssertTrue(constrained.usesCalmerSpatialMotion)
    }

    func testHomeCompletionUsesSharedCommitFeedbackAndReducedMotionFallback() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let homeFeedback = HomeActionInteractionFeedback(feedback: feedback)

        let standard = homeFeedback.commitTodayAction(accessibilityReduceMotion: false)
        let reduced = homeFeedback.commitTodayAction(accessibilityReduceMotion: true)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.meaningfulCommit, .meaningfulCommit])
        XCTAssertEqual(standard.motion, .commitSpring)
        XCTAssertFalse(standard.motionProfile.usesCalmerSpatialMotion)
        XCTAssertEqual(reduced.motion, .commitSpring)
        XCTAssertTrue(reduced.motionProfile.usesCalmerSpatialMotion)
    }

    func testHomeUndoAndRefillUseDistinctSharedFeedbackSemantics() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let homeFeedback = HomeActionInteractionFeedback(feedback: feedback)

        let undo = homeFeedback.undoTodayAction(accessibilityReduceMotion: false)
        let refill = homeFeedback.commitNewPackOrCycle(accessibilityReduceMotion: false)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.lowRiskTap, .meaningfulCommit])
        XCTAssertEqual(undo.motion, .standard)
        XCTAssertEqual(refill.motion, .commitSpring)
    }
}

private final class RecordingInteractionFeedbackPerformer: InteractionFeedbackPerforming {
    private(set) var performedIntents: [InteractionFeedback.Intent] = []

    func perform(_ intent: InteractionFeedback.Intent) {
        performedIntents.append(intent)
    }
}
