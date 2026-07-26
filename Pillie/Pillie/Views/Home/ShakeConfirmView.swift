//
//  ShakeConfirmView.swift
//  Pillie
//

import SwiftUI

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

struct ShakeConfirmView: View {
    let action: DoseScheduleAction
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @State private var shakeManager = ShakeDetectionManager()
    @State private var appeared = false
    @State private var celebrating = false
    @State private var emojiOffset: CGFloat = 0
    private let shakeFeedback = ShakeConfirmationInteractionFeedback()

    private var emoji: String { action.method.emoji }
    private var progressAnimation: Animation {
        PillieMotion.animation(for: .quick, accessibilityReduceMotion: accessibilityReduceMotion)
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            ConfettiView(isActive: celebrating && !accessibilityReduceMotion)

            VStack(spacing: 32) {
                Spacer()

                // Headline
                Text(celebrating
                    ? PillieLocalization.string("global.action.done", locale: locale)
                    : PillieLocalization.string("today.action.shake", locale: locale))
                    .font(.pillieHeadline())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Subtitle
                Text(celebrating
                    ? PillieLocalization.string("global.status.completed", locale: locale)
                    : PillieLocalization.string("today.action.mark_complete", locale: locale))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.05))

                // Progress ring + emoji
                ZStack {
                    Circle()
                        .stroke(PillieTheme.sage, lineWidth: 6)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: shakeManager.progress)
                        .stroke(
                            PillieTheme.coral,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(progressAnimation, value: shakeManager.progress)

                    Text(emoji)
                        .font(.system(size: 56))
                        .offset(y: emojiOffset)
                        .scaleEffect(accessibilityReduceMotion ? 1.0 : (celebrating ? 1.3 : 1.0))
                        .opacity(celebrating ? 1.0 : 0.94)
                        .animation(
                            PillieMotion.animation(
                                for: .rewardSpring,
                                accessibilityReduceMotion: accessibilityReduceMotion
                            ),
                            value: celebrating
                        )
                }
                .scaleEffect(accessibilityReduceMotion ? 1.0 : (emojiOffset != 0 ? 1.02 : 1.0))
                .animation(progressAnimation, value: emojiOffset)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // Shake counter
                Text("\(shakeManager.shakeCount) / \(shakeManager.requiredShakes)")
                    .font(.pillie(20, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(progressAnimation, value: shakeManager.shakeCount)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                Spacer()

                if !celebrating {
                    // Tap-to-confirm alternative (accessibility — WCAG 2.5.4)
                    Button {
                        completeShake()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 16, weight: .semibold))
                            Text(PillieLocalization.string(
                                "today.action.tap_instead",
                                locale: locale
                            ))
                        }
                        .font(.pillie(18, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: PillieTheme.ctaHeight)
                        .background(PillieTheme.sage)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("shakeTapToConfirmFallback")

                    // Cancel
                    Button {
                        shakeManager.stopDetecting()
                        onDismiss()
                    } label: {
                        Text(PillieLocalization.string("global.action.cancel", locale: locale))
                            .font(.pillie(16, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        }
        .onAppear {
            shakeManager.startDetecting()
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .onDisappear {
            shakeManager.stopDetecting()
        }
        .onChange(of: shakeManager.shakeCount) { oldValue, newValue in
            guard newValue > oldValue else { return }

            if shakeManager.isComplete {
                completeShake()
            } else {
                bounceEmoji()
                shakeFeedback.progressShake(accessibilityReduceMotion: accessibilityReduceMotion)
            }
        }
    }

    // MARK: - Private

    private func bounceEmoji() {
        guard !accessibilityReduceMotion else { return }
        withAnimation(progressAnimation) {
            emojiOffset = -16
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(progressAnimation) {
                emojiOffset = 0
            }
        }
    }

    private func completeShake() {
        guard !celebrating else { return }
        shakeManager.stopDetecting()

        // Fill progress if skipped via tap alternative
        if !shakeManager.isComplete {
            shakeManager.fillToComplete()
        }

        let feedbackResponse = shakeFeedback.completion(accessibilityReduceMotion: accessibilityReduceMotion)

        withAnimation(feedbackResponse.motionProfile.animation) {
            celebrating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onConfirm()
        }
    }
}
