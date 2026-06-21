//
//  OnboardingMotionSemanticsTests.swift
//  PillieTests
//
//  #84 — End-to-end motion / accessibility QA pass.
//
//  Pure value-type assertions (no @MainActor, no per-test reference recorder), so
//  they run cleanly on the Xcode 27 beta host — unlike the recorder-based
//  InteractionFeedbackTests, which aborts on teardown (the known @MainActor /
//  reference-type-dealloc instability). These pin the two shared contracts the
//  QA pass leans on: the single decorative-motion gate, and the proof-scene
//  feedback semantics, both via the value-type Response the methods return.
//

import XCTest

@testable import Pillie

final class OnboardingMotionSemanticsTests: XCTestCase {

    // MARK: - Shared decorative-motion gate (AC2: respect Reduce Motion)

    func testDecorativeMotionRunsOnlyWhenNotReducedAndOnStandardTier() {
        // Ambient/looping decoration (background blobs, pulse rings, breathing)
        // carries no meaning, so it must stop for Reduce Motion users and on
        // constrained devices. Every onboarding screen now consults this single
        // gate instead of re-deriving the boolean (two screens previously gated
        // on performance tier alone, ignoring Reduce Motion).
        XCTAssertTrue(
            PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: false,
                performanceTier: .standard
            )
        )
        XCTAssertFalse(
            PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: true,
                performanceTier: .standard
            )
        )
        XCTAssertFalse(
            PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: false,
                performanceTier: .constrained
            )
        )
        XCTAssertFalse(
            PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: true,
                performanceTier: .constrained
            )
        )
    }

    // MARK: - Proof-scene feedback semantics (AC2: shared motion + haptics)

    func testProofMomentsExposeSharedLockEaseAndRewardMotion() {
        // The interactive proof/diagnosis scenes (Early Value Proof comet latch,
        // Mechanism Proof lock + mark-taken, Diagnosis verified reveal) route their
        // haptic + paired motion through these shared semantics instead of calling
        // InteractionFeedback / withAnimation(.spring(...)) ad hoc — so app-seals,
        // take-the-pill, and the earned payoff feel identical everywhere.
        let feedback = OnboardingInteractionFeedback(performanceTier: .standard)

        let lock = feedback.lockProtectionMoment(accessibilityReduceMotion: false)
        let ease = feedback.easeProtectionMoment(accessibilityReduceMotion: false)
        let reward = feedback.markDueActionTaken(accessibilityReduceMotion: false)

        XCTAssertEqual(lock.motion, .commitSpring)
        XCTAssertEqual(ease.motion, .standard)
        XCTAssertEqual(reward.motion, .rewardSpring)

        // Each proof beat carries a haptic — none is silent.
        XCTAssertFalse(lock.skipsHaptics)
        XCTAssertFalse(ease.skipsHaptics)
        XCTAssertFalse(reward.skipsHaptics)

        // On a capable device with motion allowed, the spatial motion is full.
        XCTAssertFalse(lock.motionProfile.usesCalmerSpatialMotion)
        XCTAssertFalse(reward.motionProfile.usesCalmerSpatialMotion)
    }

    func testProofMomentsKeepHapticsButCalmMotionUnderReduceMotion() {
        let feedback = OnboardingInteractionFeedback(performanceTier: .standard)

        let lock = feedback.lockProtectionMoment(accessibilityReduceMotion: true)
        let ease = feedback.easeProtectionMoment(accessibilityReduceMotion: true)
        let reward = feedback.markDueActionTaken(accessibilityReduceMotion: true)

        // Haptics still fire under Reduce Motion (non-visual confirmation matters);
        // only the spatial motion downshifts to the calmer profile.
        XCTAssertFalse(lock.skipsHaptics)
        XCTAssertFalse(reward.skipsHaptics)
        XCTAssertTrue(lock.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(ease.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(reward.motionProfile.usesCalmerSpatialMotion)
    }

    func testProofMomentsCalmMotionOnConstrainedDevices() {
        let feedback = OnboardingInteractionFeedback(performanceTier: .constrained)

        let lock = feedback.lockProtectionMoment(accessibilityReduceMotion: false)
        let reward = feedback.markDueActionTaken(accessibilityReduceMotion: false)

        XCTAssertTrue(lock.motionProfile.usesCalmerSpatialMotion)
        XCTAssertTrue(reward.motionProfile.usesCalmerSpatialMotion)
    }
}
