//
//  ProtectionPlanDistractionChoicesView.swift
//  Pillie
//
//  Distraction Choices — the first plan-builder question (issue #75, Superdesign
//  draft 0344aa3e). Multi-select, including an Other catch-all: the user names
//  what usually gets in the way after a reminder. Built on the shared
//  `ProtectionPlanScaffold`. The committed answer lives in the testable
//  onboarding value core, so back navigation restores it; only a coarse,
//  low-cardinality funnel event is sent — never the raw choices.
//

import SwiftUI

struct ProtectionPlanDistractionChoicesView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    private let content = ProtectionPlanDistractionChoicesContent.default
    private let telemetry = ProductAnalyticsTelemetry.live

    @State private var selected: Set<DistractionChoice> = []
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
            isPrimaryEnabled: !selected.isEmpty,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    ForEach(content.choices) { choice in
                        ProtectionPlanSelectableRow(
                            title: choice.title,
                            symbolName: choice.symbolName,
                            isSelected: selected.contains(choice),
                            style: .checkbox
                        ) {
                            toggle(choice)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

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
            selected = model.distractionChoices
            appeared = true
        }
    }

    private func toggle(_ choice: DistractionChoice) {
        if selected.contains(choice) {
            selected.remove(choice)
        } else {
            selected.insert(choice)
        }
    }

    private func commit() {
        model.recordDistractionChoices(selected)
        telemetry.onboardingDistractionChoicesCompleted()
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

/// Shared left-aligned title + subtitle for the plan-builder question screens.
struct ProtectionPlanQuestionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.textPrimary)
                // The 42pt title fits short questions on one or two lines; a long
                // question (e.g. Failure Frequency) auto-shrinks to stay within two
                // lines instead of pushing the screen to three crowded lines.
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.pillie(17, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
