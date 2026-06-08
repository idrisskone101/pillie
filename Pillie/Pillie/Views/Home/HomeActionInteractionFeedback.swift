//
//  HomeActionInteractionFeedback.swift
//  Pillie
//

import Foundation

struct HomeActionInteractionFeedback {
    struct Response: Equatable {
        let motion: PillieMotion.Semantic
        let motionProfile: PillieMotion.Profile
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
    func commitTodayAction(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func undoTodayAction(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func commitNewPackOrCycle(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    private func response(
        feedbackIntent: InteractionFeedback.Intent,
        motion: PillieMotion.Semantic,
        accessibilityReduceMotion: Bool
    ) -> Response {
        feedback.perform(feedbackIntent)
        return Response(
            motion: motion,
            motionProfile: PillieMotion.profile(
                for: motion,
                accessibilityReduceMotion: accessibilityReduceMotion,
                performanceTier: performanceTier
            )
        )
    }
}
