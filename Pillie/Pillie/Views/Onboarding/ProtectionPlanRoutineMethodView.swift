//
//  ProtectionPlanRoutineMethodView.swift
//  Pillie
//
//  Routine Basics — Method (issue #77, Superdesign draft c8d8749d). The first routine
//  screen: the user names which contraception routine Pillie should protect. The
//  chosen method is written to the existing production model (`PillStore`), and the
//  live plan card begins assembling so the routine setup reads as one building plan.
//  Pill, Patch, and Ring are method-aware from here on via `MethodActionLanguage`.
//

import SwiftUI

struct ProtectionPlanRoutineMethodView: View {
    let progress: ProtectionPlanProgress
    let initialMethod: ContraceptiveMethod
    let onBack: () -> Void
    let onContinue: (ContraceptiveMethod) -> Void

    private let content = ProtectionPlanRoutineMethodContent.default

    // Plain @State seeded in `.onAppear` (no custom init) so the SDK-27 @State macro
    // stays well-behaved and back navigation restores the committed method.
    @State private var selected: ContraceptiveMethod = .pill
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
            isPrimaryEnabled: true,
            onPrimary: { onContinue(selected) }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    ForEach(content.choices, id: \.self) { method in
                        ProtectionPlanSelectableRow(
                            title: method.title,
                            subtitle: method.routineDescriptor,
                            symbolName: symbol(for: method),
                            isSelected: selected == method,
                            style: .radio
                        ) {
                            selected = method
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

                ProtectionPlanRoutineCard(
                    summary: ProtectionPlanRoutineSummary(method: selected),
                    animationsEnabled: animationsEnabled
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger3), value: appeared)

                Text(content.footnote)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .animation(reveal(delay: PillieTheme.stagger4), value: appeared)
            }
        }
        .onAppear {
            selected = initialMethod
            appeared = true
        }
    }

    private func symbol(for method: ContraceptiveMethod) -> String {
        switch method {
        case .pill: return "pills.fill"
        case .patch: return "square.on.square"
        case .ring: return "circle.circle"
        }
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
    ProtectionPlanRoutineMethodView(
        progress: ProtectionPlanProgress(index: 11, total: 13),
        initialMethod: .pill,
        onBack: {},
        onContinue: { _ in }
    )
}
