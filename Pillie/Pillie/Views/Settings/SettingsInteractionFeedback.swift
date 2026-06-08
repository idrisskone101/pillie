//
//  SettingsInteractionFeedback.swift
//  Pillie
//

import Foundation

struct SettingsInteractionFeedback {
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
    func openRow(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .quick,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func commitScheduleSave(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .meaningfulCommit,
            motion: .commitSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func sensitiveOrDestructiveChange(accessibilityReduceMotion: Bool) -> Response {
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
