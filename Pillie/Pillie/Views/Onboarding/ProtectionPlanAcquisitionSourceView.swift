//
//  ProtectionPlanAcquisitionSourceView.swift
//  Pillie
//
//  Acquisition Source — the final plan-builder question (issue #76, Superdesign
//  draft 3e3d657f). Single-select but optional: a real "Not now" skip path keeps it
//  from blocking onboarding. It stays a broad product signal and reuses the
//  existing `AcquisitionSource` storage + telemetry. Kept distinct from Distraction
//  Choices. Re-seeds from the persisted source on appear so back navigation
//  restores the answer.
//

import SwiftUI

struct ProtectionPlanAcquisitionSourceView: View {
    let progress: ProtectionPlanProgress
    /// The previously committed source, so back navigation re-seeds the screen.
    let initialSelection: AcquisitionSource?
    let onBack: () -> Void
    let onContinue: (AcquisitionSource) -> Void
    let onSkip: () -> Void

    private let content = ProtectionPlanAcquisitionSourceContent.default

    @State private var selected: AcquisitionSource?
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
            onPrimary: commit,
            secondaryTitle: content.skipCTA,
            onSecondary: onSkip
        ) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.eyebrow.uppercased())
                        .font(.pillie(13, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PillieTheme.coral)

                    ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    ForEach(content.choices) { source in
                        ProtectionPlanSelectableRow(
                            title: source.title,
                            isSelected: selected == source,
                            style: .radio
                        ) {
                            selected = source
                        }
                        .accessibilityIdentifier("acquisitionSource.\(source.rawValue)")
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)
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
    ProtectionPlanAcquisitionSourceView(
        progress: ProtectionPlanProgress(index: 10, total: 10),
        initialSelection: nil,
        onBack: {},
        onContinue: { _ in },
        onSkip: {}
    )
}
