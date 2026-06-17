//
//  ProtectionPlanFailureFrequencyView.swift
//  Pillie
//
//  Failure Frequency — the third plan-builder question (issue #76, Superdesign
//  draft 12612ffc). Single-select. The display labels are updated (Rarely / A few
//  times a month / Weekly / Multiple times a week) but each maps onto the existing
//  `MissFrequency` storage bucket, so the answer stays compatible with the legacy
//  reminder-plan logic. The screen re-seeds from the persisted bucket on appear so
//  back navigation restores the answer.
//

import SwiftUI

struct ProtectionPlanFailureFrequencyView: View {
    let progress: ProtectionPlanProgress
    /// The previously committed bucket, so back navigation re-seeds the screen.
    let initialSelection: MissFrequency?
    let onBack: () -> Void
    let onContinue: (MissFrequency) -> Void

    private let content = ProtectionPlanFailureFrequencyContent.default

    @State private var selected: MissFrequency?
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
                    ForEach(content.options) { option in
                        ProtectionPlanSelectableRow(
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: selected == option.bucket,
                            style: .radio
                        ) {
                            selected = option.bucket
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
            selected = initialSelection
            appeared = true
        }
    }

    private func commit() {
        guard let selected else { return }
        onContinue(selected)
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
    ProtectionPlanFailureFrequencyView(
        progress: ProtectionPlanProgress(index: 7, total: 10),
        initialSelection: nil,
        onBack: {},
        onContinue: { _ in }
    )
}
