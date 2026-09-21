import SwiftUI

struct RoutineCyclePositionSection: View {
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
                CyclePositionPackTrackIcon(
                    activeIndex: position.packTrackActiveIndex,
                    isSelected: isSelected
                )
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

/// Three blister slots with one lit — place in the pack, not time of day.
struct CyclePositionPackTrackIcon: View {
    let activeIndex: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(slotColor(for: index))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }

    private func slotColor(for index: Int) -> Color {
        let isActive = index == activeIndex
        if isSelected {
            return isActive ? PillieTheme.coral : PillieTheme.coral.opacity(0.28)
        }
        return isActive ? PillieTheme.textMuted : Color.black.opacity(0.08)
    }
}

struct RoutinePillRegimenSection: View {
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

struct RoutineFixedScheduleSection: View {
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

struct RoutineSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.pillie(12, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(PillieTheme.textMuted)
    }
}
