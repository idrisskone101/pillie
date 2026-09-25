import SwiftUI

struct ProtocolEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var selectedMethod: ContraceptiveMethod = .pill
    @State private var selectedRegimen: PillPack.PillRegimenPreset = .twentyOneSeven
    @State private var customActiveDaysText: String = "21"
    @State private var customBreakDaysText: String = "7"
    @State private var selectedCycleDay: Int = 1
    @State private var showResetConfirmation = false

    private let settingsFeedback = SettingsInteractionFeedback()

    private var customActiveDays: Int {
        let raw = Int(customActiveDaysText) ?? 21
        return min(max(raw, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
    }

    private var customBreakDays: Int {
        let raw = Int(customBreakDaysText) ?? 7
        return min(max(raw, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
    }

    private var cycleLength: Int {
        switch selectedMethod {
        case .pill:
            if selectedRegimen == .custom {
                return customActiveDays + customBreakDays
            }
            return selectedRegimen.cycleLength
        case .patch, .ring:
            return 28
        }
    }

    private var resetConfirmation: ScheduleCriticalSettingChange.Confirmation {
        ScheduleCriticalSettingChange.confirmation(
            cycleDay: selectedCycleDay,
            locale: locale
        )
    }

    var body: some View {
        let protocolPresentation = ProtocolEditorPresentation.localized(
            method: selectedMethod,
            locale: locale
        )

        VStack(spacing: 0) {
            SettingsSheetHeader(title: PillieLocalization.string(
                "settings.schedule.title",
                locale: locale
            ))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(PillieLocalization.string("settings.method.title", locale: locale))
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    Picker(PillieLocalization.string(
                        "settings.method.title",
                        locale: locale
                    ), selection: $selectedMethod) {
                        ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                            Text(method.localizedTitle(locale: locale)).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedMethod == .pill {
                        Text(PillieLocalization.string("settings.regimen.title", locale: locale))
                            .font(.pillieCaptionMedium())
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(2)

                        VStack(spacing: 10) {
                            ForEach(PillPack.PillRegimenPreset.allCases, id: \.rawValue) { regimen in
                                Button {
                                    selectedRegimen = regimen
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(regimen.localizedRoutineDisplayName(locale: locale))
                                                .font(.pillieBodyBold())
                                                .foregroundStyle(PillieTheme.textPrimary)
                                            Text(regimen.localizedScheduleSubtitle(locale: locale))
                                                .font(.pillieBody())
                                                .foregroundStyle(PillieTheme.textMuted)
                                        }
                                        Spacer()
                                        Image(systemName: selectedRegimen == regimen ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedRegimen == regimen ? PillieTheme.coral : PillieTheme.textMuted)
                                    }
                                    .padding(14)
                                    .background(PillieTheme.cardWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                                            .stroke(PillieTheme.sageHalf, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if selectedRegimen == .custom {
                            HStack(spacing: 12) {
                                customInputCard(
                                    title: protocolPresentation.customDayLabels[0],
                                    text: $customActiveDaysText
                                )
                                customInputCard(
                                    title: protocolPresentation.customDayLabels[1],
                                    text: $customBreakDaysText
                                )
                            }
                        }
                    } else {
                        Text(PillieLocalization.string("settings.schedule.title", locale: locale))
                            .font(.pillieCaptionMedium())
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(2)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(protocolPresentation.scheduleTitle)
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.8)

                            ForEach(protocolPresentation.scheduleLines, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•")
                                        .accessibilityHidden(true)
                                    Text(line)
                                        .font(.pillieBody())
                                        .foregroundStyle(PillieTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PillieTheme.cardWhite)
                            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
                            )
                    }

                    Text(PillieLocalization.string("settings.cycle_day.title", locale: locale))
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsPresentation.cycleDay(
                            day: selectedCycleDay,
                            total: cycleLength,
                            locale: locale
                        ))
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)

                        Stepper(value: $selectedCycleDay, in: 1...max(1, cycleLength)) {
                            Text(PillieLocalization.string(
                                "settings.cycle_day.adjust",
                                locale: locale
                            ))
                                .font(.pillieBody())
                                .foregroundStyle(PillieTheme.textMuted)
                        }

                        Text(PillieLocalization.string(
                            "settings.cycle_day.history_note",
                            locale: locale
                        ))
                            .font(.pillieCaption())
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .padding(16)
                    .background(PillieTheme.cardWhite)
                    .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                            .stroke(PillieTheme.sageHalf, lineWidth: 1)
                    )
                }
                .padding(20)
            }

            VStack(spacing: 12) {
                Button {
                    showResetConfirmation = true
                } label: {
                    Text(PillieLocalization.string("global.action.save", locale: locale))
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    ProductAnalyticsTelemetry.live.protocolChangeCancelled()
                    dismiss()
                } label: {
                    Text(PillieLocalization.string("global.action.cancel", locale: locale))
                }
                .buttonStyle(.pillieSecondary)
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 20)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .alert(resetConfirmation.title, isPresented: $showResetConfirmation) {
            Button(resetConfirmation.cancelTitle, role: .cancel) { }
            Button(resetConfirmation.confirmTitle, role: .destructive) {
                settingsFeedback.sensitiveOrDestructiveChange(accessibilityReduceMotion: accessibilityReduceMotion)
                store.resetAndStartFresh(
                    method: selectedMethod,
                    regimen: selectedMethod == .pill ? selectedRegimen : .twentyOneSeven,
                    customActiveDays: selectedMethod == .pill && selectedRegimen == .custom ? customActiveDays : nil,
                    customBreakDays: selectedMethod == .pill && selectedRegimen == .custom ? customBreakDays : nil,
                    cycleDay: min(max(1, selectedCycleDay), cycleLength)
                )
                ProductAnalyticsTelemetry.live.protocolChangeSaved()
                dismiss()
            }
        } message: {
            Text(resetConfirmation.body)
        }
        .onAppear(perform: seedFromStore)
        .onChange(of: selectedMethod) { _, _ in clampCycleDay() }
        .onChange(of: selectedRegimen) { _, _ in clampCycleDay() }
        .onChange(of: customActiveDaysText) { _, _ in clampCycleDay() }
        .onChange(of: customBreakDaysText) { _, _ in clampCycleDay() }
    }

    private func customInputCard(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(PillieTheme.cardWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PillieTheme.sageHalf, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func seedFromStore() {
        selectedMethod = store.pack.method
        selectedRegimen = store.pack.pillRegimen
        customActiveDaysText = "\(store.pack.customActiveDays ?? 21)"
        customBreakDaysText = "\(store.pack.customBreakDays ?? 7)"
        selectedCycleDay = store.currentDayIndex + 1
        clampCycleDay()
    }

    private func clampCycleDay() {
        selectedCycleDay = min(max(1, selectedCycleDay), max(1, cycleLength))
    }
}
