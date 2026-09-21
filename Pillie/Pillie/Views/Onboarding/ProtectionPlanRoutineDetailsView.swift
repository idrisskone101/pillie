//
//  ProtectionPlanRoutineDetailsView.swift
//  Pillie
//
//  Fast, progressive-disclosure routine setup. Coarse position and the common
//  schedule are enough to continue; exact-day and uncommon/custom controls remain
//  available without changing the values committed to PillStore.
//

import SwiftUI

struct ProtectionPlanRoutineDetailsView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (PillPack.PillRegimenPreset, Int?, Int?, Int) -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content = ProtectionPlanRoutineDetailsContent.default
    private let performanceTier = PerformanceTier.current

    // Seeded from the production pack in onAppear so Back restores committed values
    // without a custom init (important for the SDK 27 @State macro).
    @State private var draft = RoutineSetupDraft(method: .pill)
    @State private var showMore = false
    @State private var showExactDay = false
    @State private var appeared = false

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    private var scheduleSummaryText: String {
        switch draft.section {
        case .pillRegimen:
            return draft.selectedRegimen.localizedScheduleSummary()
        case .fixedSchedule:
            return draft.method.routineDescriptor
        }
    }

    private var summary: ProtectionPlanRoutineSummary {
        ProtectionPlanRoutineSummary(
            method: draft.method,
            scheduleSummary: scheduleSummaryText,
            cycleDay: draft.cycleDay
        )
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: content.primaryCTA,
            isPrimaryEnabled: true,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 22) {
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger1)

                RoutineCyclePositionSection(
                    header: content.cyclePositionHeader,
                    editExactDayLabel: content.editExactDayLabel,
                    currentPosition: CyclePosition.position(
                        forCycleDay: draft.cycleDay,
                        cycleLength: draft.cycleLength
                    ),
                    cycleDay: draft.cycleDay,
                    cycleLength: draft.cycleLength,
                    isEditingExactDay: $showExactDay,
                    onSelectPosition: { draft.selectPosition($0) },
                    onSetExactDay: { draft.setExactCycleDay($0) }
                )
                .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

                switch draft.section {
                case .pillRegimen:
                    RoutinePillRegimenSection(
                        header: content.regimenHeader,
                        moreLabel: content.moreLabel,
                        commonRegimens: draft.visibleCommonRegimens,
                        selectedRegimen: draft.selectedRegimen,
                        showMore: $showMore,
                        customActiveDays: $draft[customDays: .active],
                        customBreakDays: $draft[customDays: .breakDays],
                        onSelectRegimen: { draft.selectRegimen($0) }
                    )
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger3)
                case .fixedSchedule:
                    RoutineFixedScheduleSection(method: draft.method)
                        .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger3)
                }

                ProtectionPlanRoutineCard(summary: summary, animationsEnabled: animationsEnabled)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger4)

                Text(content.footnote)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger4)
            }
        }
        .onAppear {
            draft = RoutineSetupDraft(method: store.contraceptiveMethod, activePack: store.pack, today: store.today)
            showMore = draft.requiresMoreOptions
            showExactDay = false
            appeared = true
        }
    }

    private func commit() {
        let output = draft.commit
        onContinue(
            output.regimen,
            output.customActiveDays,
            output.customBreakDays,
            output.cycleDay
        )
    }
}

#Preview {
    ProtectionPlanRoutineDetailsView(
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _, _, _, _ in }
    )
    .environment(PillStore.previewStore())
}
