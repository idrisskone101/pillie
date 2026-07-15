//
//  ProtectionPlanFailureFrequencyView.swift
//  Pillie
//
//  Consolidated timing question (#207): failure frequency and relevant risk window.
//  Both persisted values are restored together when the user navigates back.
//

import SwiftUI

struct ProtectionPlanFailureFrequencyView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    /// The previously committed bucket, so back navigation re-seeds the screen.
    let initialSelection: MissFrequency?
    let onBack: () -> Void
    let onContinue: (MissFrequency) -> Void

    private let content = ProtectionPlanFailureFrequencyContent.default

    @State private var selection = ProtectionPlanTimingSelection()
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

                ProtectionPlanFrequencyChoicesSection(
                    options: content.options,
                    selected: selection.missFrequency,
                    onSelect: { selection.selectFrequency($0) }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

                ProtectionPlanRiskWindowChoicesSection(
                    title: content.riskWindowTitle,
                    subtitle: content.riskWindowSubtitle,
                    choices: content.riskWindows,
                    selected: selection.riskWindow,
                    onSelect: { selection.selectRiskWindow($0) }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger3), value: appeared)

                Text(content.riskWindowFootnote)
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
            selection = ProtectionPlanTimingSelection(
                missFrequency: initialSelection,
                riskWindow: model.riskWindow
            )
            appeared = true
        }
    }

    private func commit() {
        guard let frequency = selection.missFrequency,
              let riskWindow = selection.riskWindow else { return }
        model.recordRiskWindow(riskWindow)
        onContinue(frequency)
    }

    private var revealOffset: CGFloat {
        guard animationsEnabled else { return 0 }
        return appeared ? 0 : 14
    }

    private func reveal(delay: Double) -> Animation? {
        animationsEnabled ? PillieTheme.fadeInUpCurve.delay(delay) : .easeOut(duration: 0.25)
    }
}

private struct ProtectionPlanFrequencyChoicesSection: View {
    let options: [ProtectionPlanFailureFrequencyContent.Option]
    let selected: MissFrequency?
    let onSelect: (MissFrequency) -> Void

    var body: some View {
        ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(options) { option in
                ProtectionPlanSelectableChip(
                    title: option.title,
                    isSelected: selected == option.bucket,
                    allowsMultipleSelection: false
                ) {
                    onSelect(option.bucket)
                }
            }
        }
    }
}

private struct ProtectionPlanRiskWindowChoicesSection: View {
    let title: String
    let subtitle: String
    let choices: [RiskWindow]
    let selected: RiskWindow?
    let onSelect: (RiskWindow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProtectionPlanQuestionSectionHeader(title: title, subtitle: subtitle)
            ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(choices) { window in
                    ProtectionPlanSelectableChip(
                        title: window.title,
                        isSelected: selected == window,
                        allowsMultipleSelection: false
                    ) {
                        onSelect(window)
                    }
                }
            }
        }
    }
}

#Preview {
    ProtectionPlanFailureFrequencyView(
        model: ProtectionPlanOnboardingModel(),
        progress: ProtectionPlanProgressIndex.progress(for: .missFrequency),
        initialSelection: nil,
        onBack: {},
        onContinue: { _ in }
    )
}
