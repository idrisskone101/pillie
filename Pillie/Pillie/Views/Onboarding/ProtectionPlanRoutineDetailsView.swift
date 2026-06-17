//
//  ProtectionPlanRoutineDetailsView.swift
//  Pillie
//
//  Routine Basics — Details (issue #77, Superdesign draft b9b281e6). Replaces the
//  legacy seven-card regimen form. A coarse "Just starting / Mid-cycle / Near the
//  end" toggle anchors the exact cycle day (fine-tuned with a stepper); Pill users
//  pick a regimen with the three common options up front and the rest behind "More
//  options"; Patch and Ring users see their fixed schedule instead. The committed
//  answer flows through the existing production model (`PillStore.startNewProtocol`),
//  so nothing about the reminder/cycle engine changes — only the surface.
//

import SwiftUI

struct ProtectionPlanRoutineDetailsView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (PillPack.PillRegimenPreset, Int?, Int?, Int) -> Void

    @Environment(PillStore.self) private var store

    private let content = ProtectionPlanRoutineDetailsContent.default

    @State private var selectedRegimen: PillPack.PillRegimenPreset = .twentyOneSeven
    // Keyboard-free scroll-wheel selections (Int, not text) — a numberPad TextField
    // here crashed on device when the software keyboard presented inside the
    // transitioning, conditionally-mounted scaffold subtree. Wheels remove the
    // keyboard entirely, so that crash is structurally impossible.
    @State private var customActive = 21
    @State private var customBreak = 7
    @State private var cycleDay = 1
    @State private var showMore = false
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    private var method: ContraceptiveMethod { store.contraceptiveMethod }
    private var section: RoutineDetailsSection { RoutineDetailsSection(method: method) }

    private var customActiveDays: Int {
        min(max(customActive, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
    }

    private var customBreakDays: Int {
        min(max(customBreak, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
    }

    private var cycleLength: Int {
        switch method {
        case .pill:
            return selectedRegimen == .custom ? customActiveDays + customBreakDays : selectedRegimen.cycleLength
        case .patch, .ring:
            return 28
        }
    }

    private var currentPosition: CyclePosition {
        CyclePosition.position(forCycleDay: cycleDay, cycleLength: cycleLength)
    }

    private var scheduleSummaryText: String {
        switch section {
        case .pillRegimen:
            return "\(selectedRegimen.routineDisplayName) · \(selectedRegimen.scheduleSubtitle)"
        case .fixedSchedule:
            return method == .patch ? "Weekly patch · 28-day cycle" : "Monthly ring · 28-day cycle"
        }
    }

    private var summary: ProtectionPlanRoutineSummary {
        ProtectionPlanRoutineSummary(method: method, scheduleSummary: scheduleSummaryText, cycleDay: cycleDay)
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

                positionSection
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

                Group {
                    switch section {
                    case .pillRegimen:
                        regimenSection
                    case .fixedSchedule:
                        fixedScheduleSection
                    }
                }
                .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger3)

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
            seedFromStore()
            appeared = true
        }
        .onChange(of: selectedRegimen) { _, _ in clampCycleDay() }
        .onChange(of: customActive) { _, _ in clampCycleDay() }
        .onChange(of: customBreak) { _, _ in clampCycleDay() }
    }

    // MARK: - Cycle position

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(content.cyclePositionHeader)

            HStack(spacing: 8) {
                ForEach(CyclePosition.allCases) { position in
                    positionButton(position)
                }
            }

            dayStepper
        }
    }

    private func positionButton(_ position: CyclePosition) -> some View {
        let isSelected = currentPosition == position
        return Button {
            InteractionFeedback.live.perform(.choice)
            setCycleDay(position.cycleDay(in: cycleLength))
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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

    private var dayStepper: some View {
        HStack(spacing: 16) {
            stepperButton(systemName: "minus") { setCycleDay(cycleDay - 1) }
                .accessibilityLabel("Previous cycle day")

            VStack(spacing: 1) {
                Text("Day \(cycleDay)")
                    .font(.pillie(20, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .monospacedDigit()
                    .accessibilityIdentifier("routineCycleDayValue")
                Text("of \(cycleLength)")
                    .font(.pillie(12, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .frame(maxWidth: .infinity)

            stepperButton(systemName: "plus") { setCycleDay(cycleDay + 1) }
                .accessibilityLabel("Next cycle day")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(PillieTheme.sage.opacity(0.5)))
        .accessibilityElement(children: .contain)
        .accessibilityValue("Day \(cycleDay) of \(cycleLength)")
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            InteractionFeedback.live.perform(.lowRiskTap)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background(.white, in: Circle())
                .overlay { Circle().stroke(Color.black.opacity(0.06), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(systemName == "plus" ? "routineCycleDayPlus" : "routineCycleDayMinus")
    }

    // MARK: - Pill regimen

    private var regimenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(content.regimenHeader)

            VStack(spacing: 10) {
                ForEach(RoutineRegimenCatalog.common, id: \.self) { regimen in
                    regimenRow(regimen)
                }

                if showMore {
                    ForEach(RoutineRegimenCatalog.more, id: \.self) { regimen in
                        regimenRow(regimen)
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showMore = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(content.moreLabel)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(.pillie(14, weight: .bold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
                        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("routineMoreRegimens")
                }

                if selectedRegimen == .custom {
                    customInputs
                }
            }
        }
    }

    private func regimenRow(_ regimen: PillPack.PillRegimenPreset) -> some View {
        ProtectionPlanSelectableRow(
            title: regimen.routineDisplayName,
            subtitle: regimen.scheduleSubtitle,
            isSelected: selectedRegimen == regimen,
            style: .radio
        ) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { selectedRegimen = regimen }
        }
    }

    private var customInputs: some View {
        HStack(spacing: 12) {
            customWheel(title: "Active days", selection: $customActive, range: PillPack.customActiveRange)
            customWheel(title: "Break days", selection: $customBreak, range: PillPack.customBreakRange)
        }
        .padding(.top, 2)
    }

    /// Keyboard-free numeric entry: a scroll wheel bound to an Int in range, matching
    /// the Reminder Time picker. No software keyboard = the on-device numpad crash
    /// cannot occur, and any value in range is reachable instantly.
    private func customWheel(title: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
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

    // MARK: - Patch / Ring fixed schedule

    private var fixedScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(method == .patch ? "Patch schedule" : "Ring schedule")

            VStack(alignment: .leading, spacing: 12) {
                scheduleRule(icon: method == .patch ? "square.on.square" : "circle.circle",
                             text: method == .patch ? "Day 1: apply patch" : "Day 1: insert ring")
                scheduleRule(icon: "calendar",
                             text: method == .patch ? "Days 8 & 15: change patch" : "Days 2–21: ring stays in")
                scheduleRule(icon: "arrow.uturn.backward",
                             text: method == .patch ? "Day 22: remove patch" : "Day 22: remove ring")
                scheduleRule(icon: "pause.circle",
                             text: "Days 23–28: \(method == .patch ? "patch" : "ring")-free week")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
            .overlay { RoundedRectangle(cornerRadius: PillieTheme.cardRadius).stroke(Color.black.opacity(0.06), lineWidth: 1) }
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

    // MARK: - Shared

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.pillie(12, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(PillieTheme.textMuted)
    }

    // MARK: - Commit + seeding

    private func commit() {
        onContinue(
            selectedRegimen,
            selectedRegimen == .custom ? customActiveDays : nil,
            selectedRegimen == .custom ? customBreakDays : nil,
            min(max(1, cycleDay), max(1, cycleLength))
        )
    }

    private func seedFromStore() {
        let activePack = store.pack
        if method == .pill && activePack.method == .pill {
            selectedRegimen = activePack.pillRegimen
            if selectedRegimen == .custom {
                customActive = min(max(activePack.customActiveDays ?? 21, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
                customBreak = min(max(activePack.customBreakDays ?? 7, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
            }
        } else {
            selectedRegimen = .twentyOneSeven
            customActive = 21
            customBreak = 7
        }
        if activePack.method == method {
            cycleDay = activePack.cycleDayIndex(on: store.today) + 1
        } else {
            cycleDay = 1
        }
        showMore = RoutineRegimenCatalog.more.contains(selectedRegimen)
        clampCycleDay()
    }

    private func clampCycleDay() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            cycleDay = min(max(1, cycleDay), max(1, cycleLength))
        }
    }

    private func setCycleDay(_ value: Int) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            cycleDay = min(max(1, value), max(1, cycleLength))
        }
    }
}

#Preview {
    ProtectionPlanRoutineDetailsView(
        progress: ProtectionPlanProgress(index: 12, total: 13),
        onBack: {},
        onContinue: { _, _, _, _ in }
    )
    .environment(PillStore.previewStore())
}
