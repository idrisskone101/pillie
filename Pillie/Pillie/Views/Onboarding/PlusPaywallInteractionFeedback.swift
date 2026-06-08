//
//  PlusPaywallInteractionFeedback.swift
//  Pillie
//

import Foundation

struct PlusPaywallInteractionFeedback {
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
    func successfulPaidOutcome(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .success,
            motion: .rewardSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func selectPlan(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .choice,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func openPaywallOrStartPurchase(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func startRestore(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .quick,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func dismissOrContinueFree(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func unsuccessfulPaidOutcome(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: nil,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func unavailablePurchaseAction(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: nil,
            motion: .standard,
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
