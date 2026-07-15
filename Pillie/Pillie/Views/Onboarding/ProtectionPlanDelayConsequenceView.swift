//
//  ProtectionPlanDelayConsequenceView.swift
//  Pillie
//
//  Delay Consequence — the second plan-builder question (issue #75, Superdesign
//  draft aa808d90). Single-select: an emotionally specific, non-medical read on
//  what missing or delaying feels like. Replaces the old PersonalGoal screen in
//  this flow — it is collected as its own answer in the testable onboarding value
//  core. Only a coarse, low-cardinality funnel event is sent — never the answer.
//

import SwiftUI

struct ProtectionPlanDelayConsequenceView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    private let content = ProtectionPlanDelayConsequenceContent.default
    private let telemetry = ProductAnalyticsTelemetry.live

    @State private var selected: DelayConsequence?
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
            isPrimaryEnabled: selected != nil,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)

                    Text(content.helper)
                        .font(.pillie(14, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    ForEach(content.choices) { consequence in
                        ProtectionPlanSelectableRow(
                            title: consequence.title,
                            symbolName: consequence.symbolName,
                            isSelected: selected == consequence,
                            style: .radio
                        ) {
                            selected = consequence
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

                Text(content.footnote)
                    .font(.pillie(13, weight: .regular))
                    .italic()
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .opacity(appeared ? 1 : 0)
                    .animation(reveal(delay: PillieTheme.stagger3), value: appeared)
            }
        }
        .onAppear {
            // Restore the committed answer so back navigation re-seeds the screen.
            selected = model.delayConsequence
            appeared = true
        }
    }

    private func commit() {
        model.recordDelayConsequence(selected)
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
    ProtectionPlanDelayConsequenceView(
        model: ProtectionPlanOnboardingModel(),
        progress: ProtectionPlanProgressIndex.progress(for: .goal),
        onBack: {},
        onContinue: {}
    )
}
