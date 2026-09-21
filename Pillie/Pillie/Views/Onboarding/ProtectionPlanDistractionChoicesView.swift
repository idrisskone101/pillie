//
//  ProtectionPlanDistractionChoicesView.swift
//  Pillie
//
//  Consolidated intent question (#207): what gets in the way and what better
//  follow-through should provide. Both existing answer fields remain committed.
//

import SwiftUI

struct ProtectionPlanDistractionChoicesView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    private let content = ProtectionPlanDistractionChoicesContent.default
    private let telemetry = ProductAnalyticsTelemetry.live

    @State private var selection = ProtectionPlanIntentSelection()
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: content.primaryCTA,
            isPrimaryEnabled: selection.canContinue,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                ProtectionPlanIntentChoicesSection(
                    choices: content.choices,
                    selected: selection.distractionChoices,
                    onSelect: { selection.toggle($0) }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

                ProtectionPlanDesiredOutcomeSection(
                    title: content.desiredOutcomeTitle,
                    subtitle: content.desiredOutcomeSubtitle,
                    outcomes: content.desiredOutcomes,
                    selected: selection.desiredOutcome,
                    onSelect: { selection.selectOutcome($0) }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger3), value: appeared)

                Text(content.helper)
                    .font(.pillie(13, weight: .regular))
                    .italic()
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                    .opacity(appeared ? 1 : 0)
                    .animation(reveal(delay: PillieTheme.stagger3), value: appeared)
            }
        }
        .onAppear {
            // Restore the committed answer so back navigation re-seeds the screen.
            selection = ProtectionPlanIntentSelection(
                distractionChoices: model.distractionChoices,
                desiredOutcome: model.delayConsequence
            )
            appeared = true
        }
    }

    private func commit() {
        guard let desiredOutcome = selection.desiredOutcome else { return }
        model.recordDistractionChoices(selection.distractionChoices)
        model.recordDelayConsequence(desiredOutcome)
        telemetry.onboardingDistractionChoicesCompleted()
        telemetry.onboardingDelayConsequenceCompleted()
        onContinue()
    }

    private var revealOffset: CGFloat {
        guard animationsEnabled else { return 0 }
        return appeared ? 0 : 14
    }

    private func reveal(delay: Double) -> Animation? {
        animationsEnabled ? PillieTheme.fadeInUpCurve.delay(delay) : .easeOut(duration: 0.25)
    }
}

#Preview {
    ProtectionPlanDistractionChoicesView(
        model: ProtectionPlanOnboardingModel(),
        progress: ProtectionPlanProgressIndex.progress(for: .painPoints),
        onBack: {},
        onContinue: {}
    )
}
