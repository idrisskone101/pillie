//
//  ProtectionPlanOnboardingShell.swift
//  Pillie
//
//  Production flow container for Protection Plan Onboarding. Routes the rendered
//  steps (Welcome -> Analytics Consent), preserves committed answers via the
//  state model, gates Product Analytics Telemetry on the consent decision, and
//  signals the handoff into the rest of onboarding once the intro is complete.
//

import SwiftUI

struct ProtectionPlanOnboardingShell: View {
    let model: ProtectionPlanOnboardingModel
    /// Whether the launch splash is still covering the screen. Welcome holds its
    /// entrance choreography until this clears so the animation is actually seen.
    var splashActive: Bool = false
    /// Called once the Welcome + Analytics Consent intro has been committed.
    let onIntroFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    /// Drives the slide direction: forward steps push the new screen in from the
    /// trailing edge while the old one exits to the leading edge (a clean
    /// left-to-right push); back navigation reverses it.
    @State private var goingForward = true

    /// Progress shown on the Analytics Consent screen, matching the Superdesign
    /// draft ("STEP 2/10"). Welcome intentionally hides progress.
    private var analyticsConsentProgress: ProtectionPlanProgress {
        ProtectionPlanProgress(index: 2, total: 10)
    }

    /// Progress shown on the Early Value Proof ("STEP 3/10").
    private var earlyValueProofProgress: ProtectionPlanProgress {
        ProtectionPlanProgress(index: 3, total: 10)
    }

    var body: some View {
        ZStack {
            switch model.currentStep {
            case .welcome:
                ProtectionPlanWelcomeView(onBuildPlan: buildPlan, splashActive: splashActive)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))

            case .analyticsConsent:
                ProtectionPlanAnalyticsConsentView(
                    progress: analyticsConsentProgress,
                    onBack: goBack,
                    onAllow: { decideConsent(allowed: true) },
                    onDecline: { decideConsent(allowed: false) }
                )
                .transition(pushTransition)

            case .earlyValueProof:
                ProtectionPlanEarlyValueProofView(
                    progress: earlyValueProofProgress,
                    onBack: goBack,
                    onContinue: proofContinue
                )
                .transition(pushTransition)

            default:
                // Intro complete (handoff sentinel reached): hand off to the first
                // question and the rest of onboarding.
                Color.clear
                    .onAppear(perform: onIntroFinished)
            }
        }
    }

    // MARK: - Navigation

    private func buildPlan() {
        InteractionFeedback.live.perform(.meaningfulCommit)
        advance()
    }

    private func proofContinue() {
        InteractionFeedback.live.perform(.meaningfulCommit)
        advance() // earlyValueProof -> handoff sentinel
        // Hand off synchronously so there is no blank frame between the proof and
        // the first question.
        if model.hasFinishedIntro {
            onIntroFinished()
        }
    }

    private func advance() {
        goingForward = true
        withAnimation(transitionAnimation) {
            model.advance()
        }
    }

    private func goBack() {
        InteractionFeedback.live.perform(.lowRiskTap)
        goingForward = false
        withAnimation(transitionAnimation) {
            model.goBack()
        }
    }

    private func decideConsent(allowed: Bool) {
        // Distinct feedback: granting is a success, declining is a soft tap.
        InteractionFeedback.live.perform(allowed ? .success : .lowRiskTap)
        // Commit the answer, then gate telemetry. Declining must not block the flow.
        model.recordAnalyticsConsent(allowed: allowed)
        AnalyticsManager.shared.setAnalyticsEnabled(allowed)
        advance()
        // Hand off synchronously once the intro is committed so there is no blank
        // frame between Analytics Consent and the next onboarding step.
        if model.hasFinishedIntro {
            onIntroFinished()
        }
    }

    private var transitionAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.45, dampingFraction: 0.86)
    }

    /// A directional push: the incoming screen enters from one edge while the
    /// outgoing screen leaves toward the opposite edge, so forward reads
    /// left-to-right and back reads right-to-left.
    private var pushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading),
            removal: .move(edge: goingForward ? .leading : .trailing)
        )
    }
}
