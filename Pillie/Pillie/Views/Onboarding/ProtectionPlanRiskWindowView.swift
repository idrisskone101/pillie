//
//  ProtectionPlanRiskWindowView.swift
//  Pillie
//
//  Risk Window — the fourth plan-builder question (issue #76, Superdesign draft
//  bae7eb8a). Single-select: when the user is most likely to drift after a
//  reminder. In v1 this is personalization / copy only — the clarifier makes clear
//  it does not change the actual blocking schedule. The committed answer lives in
//  the testable onboarding value core, so back navigation restores it; only a
//  coarse, low-cardinality funnel event is sent — never the chosen window.
//

import SwiftUI

struct ProtectionPlanRiskWindowView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    private let content = ProtectionPlanRiskWindowContent.default

    @State private var selected: RiskWindow?
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
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    ForEach(content.choices) { window in
                        ProtectionPlanSelectableRow(
                            title: window.title,
                            subtitle: window.subtitle,
                            isSelected: selected == window,
                            style: .radio
                        ) {
                            selected = window
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
            selected = model.riskWindow
            appeared = true
        }
    }

    private func commit() {
        model.recordRiskWindow(selected)
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
    ProtectionPlanRiskWindowView(
        model: ProtectionPlanOnboardingModel(),
        progress: ProtectionPlanProgress(index: 8, total: 10),
        onBack: {},
        onContinue: {}
    )
}
