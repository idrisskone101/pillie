//
//  ProtectionPlanRoutineDetailsView.swift
//  Pillie
//
//  Fast, progressive-disclosure routine setup. Coarse position and the common
//  schedule are enough to continue; exact-day and uncommon/custom controls remain
//  available without changing the values committed to PillStore.
//

import SwiftUI

enum RoutineExactDayCardAction: Equatable {
    case expand
    case collapse

    static func resolve(isEditingExactDay: Bool) -> Self {
        isEditingExactDay ? .collapse : .expand
    }
}

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

private struct RoutineCyclePositionSection: View {
    let header: String
    let editExactDayLabel: String
    let currentPosition: CyclePosition
    let cycleDay: Int
    let cycleLength: Int
    @Binding var isEditingExactDay: Bool
    let onSelectPosition: (CyclePosition) -> Void
    let onSetExactDay: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoutineSectionHeader(text: header)

            HStack(spacing: 8) {
                ForEach(CyclePosition.allCases) { position in
                    positionButton(position)
                }
            }

            exactDayDisclosure

            if isEditingExactDay {
                exactDayStepper
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func positionButton(_ position: CyclePosition) -> some View {
        let isSelected = currentPosition == position
        return Button {
            InteractionFeedback.live.perform(.choice)
            onSelectPosition(position)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: position.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                Text(position.title)
                    .font(.pillie(13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? PillieTheme.coral : PillieTheme.textMuted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? PillieTheme.coralLight.opacity(0.8) : .white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? PillieTheme.coral : Color.black.opacity(0.07), lineWidth: isSelected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(position.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var exactDayDisclosure: some View {
        Button {
            let action = RoutineExactDayCardAction.resolve(
                isEditingExactDay: isEditingExactDay
            )
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingExactDay = action == .expand
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        PillieLocalization.formatted(
                            "onboarding.cycle_position.day_of_total",
                            arguments: cycleDay,
                            cycleLength
                        )
                    )
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .monospacedDigit()
                        .accessibilityIdentifier("routineCycleDayValue")
                    Text(PillieLocalization.string("onboarding.cycle_position.calculated"))
                        .font(.pillie(12, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Text(isEditingExactDay ? PillieLocalization.string("global.action.done") : editExactDayLabel)
                    Image(systemName: isEditingExactDay ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.pillie(13, weight: .bold))
                .foregroundStyle(PillieTheme.coral)
                .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 18).fill(PillieTheme.sage.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routineEditExactDay")
        .accessibilityValue(
            PillieLocalization.string(
                isEditingExactDay ? "accessibility.expanded" : "accessibility.collapsed"
            )
        )
    }

    private var exactDayStepper: some View {
        HStack(spacing: 16) {
            stepperButton(systemName: "minus", label: PillieLocalization.string("onboarding.cycle_position.previous")) {
                onSetExactDay(cycleDay - 1)
            }

            Text(
                PillieLocalization.formatted(
                    "onboarding.cycle_position.day",
                    arguments: cycleDay
                )
            )
                .font(.pillie(20, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            stepperButton(systemName: "plus", label: PillieLocalization.string("onboarding.cycle_position.next")) {
                onSetExactDay(cycleDay + 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(PillieTheme.sage.opacity(0.5)))
        .accessibilityElement(children: .contain)
        .accessibilityValue(
            PillieLocalization.formatted(
                "onboarding.cycle_position.day_of_total",
                arguments: cycleDay,
                cycleLength
            )
        )
    }

    private func stepperButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            InteractionFeedback.live.perform(.lowRiskTap)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
                .overlay { Circle().stroke(Color.black.opacity(0.06), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(systemName == "plus" ? "routineCycleDayPlus" : "routineCycleDayMinus")
    }
}

private struct RoutinePillRegimenSection: View {
    let header: String
    let moreLabel: String
    let commonRegimens: [PillPack.PillRegimenPreset]
    let selectedRegimen: PillPack.PillRegimenPreset
    @Binding var showMore: Bool
    @Binding var customActiveDays: Int
    @Binding var customBreakDays: Int
    let onSelectRegimen: (PillPack.PillRegimenPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoutineSectionHeader(text: header)

            VStack(spacing: 10) {
                ForEach(commonRegimens, id: \.self) { regimen in
                    regimenRow(regimen)
                }

                DisclosureGroup(isExpanded: $showMore) {
                    VStack(spacing: 10) {
                        ForEach(RoutineRegimenCatalog.more, id: \.self) { regimen in
                            regimenRow(regimen)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text(moreLabel)
                        .font(.pillie(14, weight: .bold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .tint(PillieTheme.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1) }
                .accessibilityIdentifier("routineMoreRegimens")
                .accessibilityValue(
                    PillieLocalization.string(
                        showMore ? "accessibility.expanded" : "accessibility.collapsed"
                    )
                )

                if selectedRegimen == .custom {
                    HStack(spacing: 12) {
                        customWheel(
                            title: PillieLocalization.string("onboarding.regimen.active_days"),
                            selection: $customActiveDays,
                            range: PillPack.customActiveRange
                        )
                        customWheel(
                            title: PillieLocalization.string("onboarding.regimen.break_days"),
                            selection: $customBreakDays,
                            range: PillPack.customBreakRange
                        )
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func regimenRow(_ regimen: PillPack.PillRegimenPreset) -> some View {
        ProtectionPlanSelectableRow(
            title: regimen.localizedRoutineDisplayName(),
            subtitle: regimen.localizedScheduleSubtitle(),
            isSelected: selectedRegimen == regimen,
            style: .radio
        ) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { onSelectRegimen(regimen) }
        }
    }

    private func customWheel(
        title: String,
        selection: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.pillie(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(PillieTheme.textMuted)
            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text("\(value)")
                        .font(.pillie(16, weight: .bold))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1) }
            .clipped()
            .accessibilityLabel(title)
            .accessibilityValue("\(selection.wrappedValue)")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RoutineFixedScheduleSection: View {
    let method: ContraceptiveMethod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoutineSectionHeader(
                text: PillieLocalization.string(
                    method == .patch ? "onboarding.fixed.patch.title" : "onboarding.fixed.ring.title"
                )
            )

            VStack(alignment: .leading, spacing: 12) {
                scheduleRule(
                    icon: method == .patch ? "square.on.square" : "circle.circle",
                    text: PillieLocalization.string(
                        method == .patch ? "onboarding.fixed.patch.day1" : "onboarding.fixed.ring.day1"
                    )
                )
                scheduleRule(
                    icon: "calendar",
                    text: PillieLocalization.string(
                        method == .patch ? "onboarding.fixed.patch.day8" : "onboarding.fixed.ring.day2"
                    )
                )
                scheduleRule(
                    icon: "arrow.uturn.backward",
                    text: PillieLocalization.string(
                        method == .patch ? "onboarding.fixed.patch.day22" : "onboarding.fixed.ring.day22"
                    )
                )
                scheduleRule(
                    icon: "pause.circle",
                    text: PillieLocalization.string(
                        method == .patch ? "onboarding.fixed.patch.break" : "onboarding.fixed.ring.break"
                    )
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private func scheduleRule(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 22)
            Text(text)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RoutineSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.pillie(12, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(PillieTheme.textMuted)
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
