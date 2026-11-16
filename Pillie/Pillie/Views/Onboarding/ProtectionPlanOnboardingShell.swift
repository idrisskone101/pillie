//
//  ProtectionPlanOnboardingShell.swift
//  Pillie
//
//  Production flow container for the Protection Plan Onboarding intro. Renders
//  Welcome, then signals the handoff into the rest of onboarding.
//

import SwiftUI

struct ProtectionPlanOnboardingShell: View {
    let model: ProtectionPlanOnboardingModel
    /// Whether the launch splash is still covering the screen. Welcome holds its
    /// entrance choreography until this clears so the animation is actually seen.
    var splashActive: Bool = false
    let onIntroFinished: () -> Void

    var body: some View {
        ZStack {
            switch model.currentStep {
            case .welcome:
                ProtectionPlanWelcomeView(onBuildPlan: buildPlan, splashActive: splashActive)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))

            default:
                Color.clear
                    .onAppear(perform: onIntroFinished)
            }
        }
    }

    private func buildPlan() {
        InteractionFeedback.live.perform(.meaningfulCommit)
        model.advance()
        // Synchronous, so no blank frame shows between Welcome and the first question.
        onIntroFinished()
    }
}
