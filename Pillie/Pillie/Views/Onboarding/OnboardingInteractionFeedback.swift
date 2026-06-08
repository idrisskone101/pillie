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
