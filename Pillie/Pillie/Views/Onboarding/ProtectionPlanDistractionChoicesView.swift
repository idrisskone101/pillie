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

private struct ProtectionPlanIntentChoicesSection: View {
    let choices: [DistractionChoice]
    let selected: Set<DistractionChoice>
    let onSelect: (DistractionChoice) -> Void

    var body: some View {
        ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(choices) { choice in
                ProtectionPlanSelectableChip(
                    title: choice.title,
                    isSelected: selected.contains(choice)
                ) {
                    onSelect(choice)
                }
            }
        }
    }
}

private struct ProtectionPlanDesiredOutcomeSection: View {
    let title: String
    let subtitle: String
    let outcomes: [DelayConsequence]
    let selected: DelayConsequence?
    let onSelect: (DelayConsequence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProtectionPlanQuestionSectionHeader(title: title, subtitle: subtitle)
            ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(outcomes) { outcome in
                    ProtectionPlanSelectableChip(
                        title: outcome.desiredOutcomeTitle,
                        isSelected: selected == outcome,
                        allowsMultipleSelection: false
                    ) {
                        onSelect(outcome)
                    }
                }
            }
        }
    }
}

/// Secondary heading inside a consolidated question screen. It preserves the
/// primary screen title's hierarchy while keeping both sections easy to scan.
struct ProtectionPlanQuestionSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.pillie(24, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
                // question (including longer localized variants) can use a third
                // line before scaling down, avoiding clipped Italian copy.
                .lineLimit(3)
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
