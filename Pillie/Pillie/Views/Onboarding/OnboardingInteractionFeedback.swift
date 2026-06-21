//
//  OnboardingInteractionFeedback.swift
//  Pillie
//

import Foundation

struct OnboardingInteractionFeedback {
    struct Response: Equatable {
        let motion: PillieMotion.Semantic
        let motionProfile: PillieMotion.Profile
        let skipsHaptics: Bool
    }

    private let feedback: InteractionFeedback
    private let performanceTier: PerformanceTier

    init(
        feedback: InteractionFeedback = .live,
        performanceTier: PerformanceTier = .standard
    ) {
        self.feedback = feedback
        self.performanceTier = performanceTier
    }

    @discardableResult
    func selectChoice(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .choice,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func continueSetupStep(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func continueDemoMoment(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func requestOrSkipReview(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func openSoftPaywallOrUpgrade(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func continueFreePath(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func ambientLoop(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: nil,
            motion: .entrance,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    // MARK: - Interactive proof / diagnosis moments
    //
    // The bespoke proof scenes share one three-beat narrative — apps seal shut,
    // a light reversible adjustment, then the earned release when the user takes
    // their pill. Routing each beat through these methods keeps the haptic intent
    // and the paired commit/reward motion identical across Early Value Proof,
    // Mechanism Proof, and the Diagnosis verified reveal.

    /// A significant proof beat: protected apps seal/lock shut (EVP comet latch,
    /// Mechanism lock-in, the final shake before resolve).
    @discardableResult
    func lockProtectionMoment(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    /// A light, low-stakes proof touch: dragging the catch back below the latch,
    /// an intermediate shake tick, a "drag me" hint, or replaying the demo.
    @discardableResult
    func easeProtectionMoment(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    /// The earned payoff: the user marks the due action taken and the apps release
    /// (EVP resolve, Mechanism mark-taken, Diagnosis verified-plan reveal).
    @discardableResult
    func markDueActionTaken(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .success,
            motion: .rewardSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    private func response(
        feedbackIntent: InteractionFeedback.Intent?,
        motion: PillieMotion.Semantic,
        accessibilityReduceMotion: Bool
    ) -> Response {
        if let feedbackIntent {
            feedback.perform(feedbackIntent)
        }

        return Response(
            motion: motion,
            motionProfile: PillieMotion.profile(
                for: motion,
                accessibilityReduceMotion: accessibilityReduceMotion,
                performanceTier: performanceTier
            ),
            skipsHaptics: feedbackIntent == nil
        )
    }
}
