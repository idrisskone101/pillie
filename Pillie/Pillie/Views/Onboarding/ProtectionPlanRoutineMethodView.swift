//
//  ProtectionPlanRoutineMethodView.swift
//  Pillie
//
//  Routine Basics — Method (issue #77, Superdesign draft c8d8749d). The first routine
//  screen: the user names which contraception routine Pillie should protect.
//  Pill, Patch, and Ring are method-aware from here on via `MethodActionLanguage`.
//

import SwiftUI

struct ProtectionPlanRoutineMethodView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (ContraceptiveMethod) -> Void

    private let content = ProtectionPlanRoutineMethodContent.default

    // Seeded before the first frame, so back navigation never flashes the Pill row.
    @State private var selected: ContraceptiveMethod
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    init(
        progress: ProtectionPlanProgress,
        initialMethod: ContraceptiveMethod,
        onBack: @escaping () -> Void,
        onContinue: @escaping (ContraceptiveMethod) -> Void
    ) {
        self.progress = progress
        self.onBack = onBack
        self.onContinue = onContinue
        _selected = State(initialValue: initialMethod)
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
                            iconImageName: method.iconImageName,
                            iconImageSize: method.iconImageSize,
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
            }
        }
        .onAppear {
            appeared = true
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
        progress: ProtectionPlanProgressIndex.progress(for: .method),
        initialMethod: .pill,
        onBack: {},
        onContinue: { _ in }
    )
}
