struct ShakeConfirmationInteractionFeedback {
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
    func progressShake(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .quick,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func completion(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .success,
            motion: .rewardSpring,
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
