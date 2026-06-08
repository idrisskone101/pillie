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

    func testShakeProgressUsesRestrainedSharedFeedbackAndReducedMotionFallback() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let shakeFeedback = ShakeConfirmationInteractionFeedback(feedback: feedback)

        let standard = shakeFeedback.progressShake(accessibilityReduceMotion: false)
        let reduced = shakeFeedback.progressShake(accessibilityReduceMotion: true)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.lowRiskTap, .lowRiskTap])
        XCTAssertEqual(standard.motion, .quick)
        XCTAssertFalse(standard.motionProfile.usesCalmerSpatialMotion)
        XCTAssertEqual(reduced.motion, .quick)
        XCTAssertTrue(reduced.motionProfile.usesCalmerSpatialMotion)
    }

    func testShakeCompletionUsesSuccessFeedbackAndRewardMotion() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let shakeFeedback = ShakeConfirmationInteractionFeedback(feedback: feedback)

        let standard = shakeFeedback.completion(accessibilityReduceMotion: false)
        let reduced = shakeFeedback.completion(accessibilityReduceMotion: true)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.success, .success])
        XCTAssertEqual(standard.motion, .rewardSpring)
        XCTAssertFalse(standard.motionProfile.usesCalmerSpatialMotion)
        XCTAssertEqual(reduced.motion, .rewardSpring)
        XCTAssertTrue(reduced.motionProfile.usesCalmerSpatialMotion)
    }

    func testSettingsBrowsingSavesAndSensitiveActionsUseAppropriateSharedFeedback() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let settingsFeedback = SettingsInteractionFeedback(feedback: feedback)

        let browse = settingsFeedback.openRow(accessibilityReduceMotion: false)
        let save = settingsFeedback.commitScheduleSave(accessibilityReduceMotion: false)
        let destructive = settingsFeedback.sensitiveOrDestructiveChange(accessibilityReduceMotion: false)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.lowRiskTap, .meaningfulCommit])
        XCTAssertEqual(browse.motion, .quick)
        XCTAssertEqual(save.motion, .commitSpring)
        XCTAssertEqual(destructive.motion, .standard)
        XCTAssertTrue(destructive.skipsHaptics)
    }

    func testPlusSuccessfulPurchaseAndRestoreUseSuccessFeedbackAndRewardMotion() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let plusFeedback = PlusPaywallInteractionFeedback(feedback: feedback)

        let purchase = plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: false)
        let restore = plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: true)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.success, .success])
        XCTAssertEqual(purchase.motion, .rewardSpring)
        XCTAssertFalse(purchase.motionProfile.usesCalmerSpatialMotion)
        XCTAssertEqual(restore.motion, .rewardSpring)
        XCTAssertTrue(restore.motionProfile.usesCalmerSpatialMotion)
    }

    func testPlusFailedCancelledAndUnavailableOutcomesStayCalmWithoutHaptics() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let plusFeedback = PlusPaywallInteractionFeedback(feedback: feedback)

        let failed = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: false)
        let cancelled = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: true)
        let unavailable = plusFeedback.unavailablePurchaseAction(accessibilityReduceMotion: false)

        XCTAssertEqual(feedbackRecorder.performedIntents, [])
        XCTAssertEqual(failed.motion, .standard)
        XCTAssertTrue(failed.skipsHaptics)
        XCTAssertEqual(cancelled.motion, .standard)
        XCTAssertTrue(cancelled.motionProfile.usesCalmerSpatialMotion)
        XCTAssertEqual(unavailable.motion, .standard)
        XCTAssertTrue(unavailable.skipsHaptics)
    }

    func testPlusPlanUpsellAndFreePathActionsUseRestrainedSharedFeedback() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let plusFeedback = PlusPaywallInteractionFeedback(feedback: feedback)

        let plan = plusFeedback.selectPlan(accessibilityReduceMotion: false)
        let upgrade = plusFeedback.openPaywallOrStartPurchase(accessibilityReduceMotion: false)
        let restore = plusFeedback.startRestore(accessibilityReduceMotion: false)
        let dismiss = plusFeedback.dismissOrContinueFree(accessibilityReduceMotion: true)

        XCTAssertEqual(
            feedbackRecorder.performedIntents,
            [.choice, .meaningfulCommit, .lowRiskTap, .lowRiskTap]
        )
        XCTAssertEqual(plan.motion, .commitSpring)
        XCTAssertEqual(upgrade.motion, .commitSpring)
        XCTAssertEqual(restore.motion, .quick)
        XCTAssertEqual(dismiss.motion, .standard)
        XCTAssertTrue(dismiss.motionProfile.usesCalmerSpatialMotion)
    }

    func testOnboardingChoicesContinueAndReviewUseGuidedSharedFeedback() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let onboardingFeedback = OnboardingInteractionFeedback(feedback: feedback)

        let choice = onboardingFeedback.selectChoice(accessibilityReduceMotion: false)
        let setupContinue = onboardingFeedback.continueSetupStep(accessibilityReduceMotion: false)
        let demoContinue = onboardingFeedback.continueDemoMoment(accessibilityReduceMotion: false)
        let review = onboardingFeedback.requestOrSkipReview(accessibilityReduceMotion: true)

        XCTAssertEqual(
            feedbackRecorder.performedIntents,
            [.choice, .meaningfulCommit, .lowRiskTap, .lowRiskTap]
        )
        XCTAssertEqual(choice.motion, .commitSpring)
        XCTAssertEqual(setupContinue.motion, .commitSpring)
        XCTAssertEqual(demoContinue.motion, .standard)
        XCTAssertEqual(review.motion, .standard)
        XCTAssertTrue(review.motionProfile.usesCalmerSpatialMotion)
    }

    func testOnboardingPaywallFreePathAndAmbientLoopsStayRestrained() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        let feedback = InteractionFeedback(performer: feedbackRecorder)
        let onboardingFeedback = OnboardingInteractionFeedback(
            feedback: feedback,
            performanceTier: .constrained
        )

        let softPaywall = onboardingFeedback.openSoftPaywallOrUpgrade(accessibilityReduceMotion: false)
        let freePath = onboardingFeedback.continueFreePath(accessibilityReduceMotion: false)
        let ambient = onboardingFeedback.ambientLoop(accessibilityReduceMotion: false)

        XCTAssertEqual(feedbackRecorder.performedIntents, [.meaningfulCommit, .lowRiskTap])
        XCTAssertEqual(softPaywall.motion, .commitSpring)
        XCTAssertEqual(freePath.motion, .standard)
        XCTAssertEqual(ambient.motion, .entrance)
        XCTAssertTrue(softPaywall.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(freePath.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(ambient.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(ambient.skipsHaptics)
    }
}

private final class RecordingInteractionFeedbackPerformer: InteractionFeedbackPerforming {
    private(set) var performedIntents: [InteractionFeedback.Intent] = []

    func perform(_ intent: InteractionFeedback.Intent) {
        performedIntents.append(intent)
    }
}
