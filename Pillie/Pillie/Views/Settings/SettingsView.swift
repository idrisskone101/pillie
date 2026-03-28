//
//  SettingsView.swift
//  Pillie
//

import SwiftUI
import StoreKit
import FamilyControls

struct SettingsView: View {
    @Environment(PillStore.self) var store
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showTimeEditor = false
    @State private var showIntervalEditor = false
    @State private var showRefillReminderEditor = false
    @State private var showProtocolEditor = false
    @State private var showCycleDayEditor = false
    @State private var showBlockedAppsEditor = false
    @State private var showBlockingUpsell = false
    @State private var showPaywall = false
    @State private var showManageSubscription = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PrimaryTitleAnchor(
                    title: "Settings",
                    titleFont: .pillieExtraBold(36),
                    showsAccessorySlot: true,
                    accessory: nil
                )
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // MARK: - My Pillie
                sectionHeader("MY PILLIE")
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                settingsCard {
                    Button { showProtocolEditor = true } label: {
                        settingsRow("Contraceptive Type", value: protocolSummary)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button { showTimeEditor = true } label: {
                        settingsRow("Reminder Time", value: store.nextReminderTime)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button { showIntervalEditor = true } label: {
                        settingsRow("Auto-Reminder Interval", value: store.autoReminderIntervalDisplay)
                    }
                    .buttonStyle(.plain)
                    if store.pack.method != .ring {
                        divider
                        Button { showRefillReminderEditor = true } label: {
                            settingsRow(supplyReminderTitle, value: supplyReminderValue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // MARK: - Cycle
                sectionHeader("CYCLE")
                    .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                settingsCard {
                    Button { showCycleDayEditor = true } label: {
                        settingsRow("Current Day in Cycle", value: "Day \(store.currentDayIndex + 1) of \(store.pack.cycleLength)")
                    }
                    .buttonStyle(.plain)
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                // MARK: - Blocking
                sectionHeader("BLOCKING")
                    .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                settingsCard {
                    if SubscriptionManager.shared.isPlus {
                        Button { showBlockedAppsEditor = true } label: {
                            settingsRow("Blocked Apps", value: blockingStatusSummary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { showBlockingUpsell = true } label: {
                            settingsRow("Blocked Apps", value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showBlockingUpsell) {
                            PlusUpsellSheet.appBlocking()
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.hidden)
                        }
                    }
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.2))

                // MARK: - Account
                sectionHeader("ACCOUNT")
                    .modifier(FadeInUp(appeared: appeared, delay: 0.2))

                settingsCard {
                    Button {
                        if SubscriptionManager.shared.isPlus {
                            showManageSubscription = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        settingsRow(
                            "Subscription",
                            value: SubscriptionManager.shared.isPlus ? "Pillie Plus" : "Free Plan",
                            valueColor: SubscriptionManager.shared.isPlus ? PillieTheme.coral : PillieTheme.textPrimary
                        )
                    }
                    .buttonStyle(.plain)
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                // Handwriting accent
                Text("you're doing amazing!")
                    .font(.pillieHandwriting())
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .rotationEffect(.degrees(-2))
                    .padding(.top, 8)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
            .padding(.top, PillieTheme.scrollTopPadding)
            .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .sheet(isPresented: $showTimeEditor) {
            ReminderTimeEditor(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showIntervalEditor) {
            AutoReminderIntervalEditor(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showRefillReminderEditor) {
            RefillReminderThresholdEditor(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showProtocolEditor) {
            ProtocolEditor(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCycleDayEditor) {
            CycleDayEditor(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showBlockedAppsEditor) {
            BlockedAppsEditor()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                onBack: { showPaywall = false },
                onContinue: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pillieCaptionMedium())
            .foregroundStyle(PillieTheme.textMuted)
            .tracking(2)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(PillieTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    private func settingsRow(_ label: String, value: String, valueColor: Color = PillieTheme.textMuted, showChevron: Bool = true, showLock: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Spacer()

            if showLock {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
            }

            Text(value)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(valueColor)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(PillieTheme.sage.opacity(0.3))
            .frame(height: 0.5)
            .padding(.leading, 20)
    }

    private var blockingStatusSummary: String {
        AppBlockingManager.shared.statusSummary
    }

    private var protocolSummary: String {
        switch store.pack.method {
        case .pill:
            return "Pill (\(store.pack.pillRegimen.title))"
        case .patch:
            return "Patch"
        case .ring:
            return "Ring"
        }
    }

    private var supplyReminderTitle: String {
        switch store.pack.method {
        case .patch:
            return "Restock Reminder"
        case .pill, .ring:
            return "Refill Reminder"
        }
    }

    private var supplyReminderValue: String {
        switch store.pack.method {
        case .patch:
            return store.patchRestockReminderThresholdDisplay
        case .pill, .ring:
            return store.refillReminderThresholdDisplay
        }
    }
}

// MARK: - Protocol Editor

private struct ProtocolEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: ContraceptiveMethod = .pill
    @State private var selectedRegimen: PillPack.PillRegimenPreset = .twentyOneSeven
    @State private var customActiveDaysText: String = "21"
    @State private var customBreakDaysText: String = "7"
    @State private var selectedCycleDay: Int = 1
    @State private var showResetConfirmation = false

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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Capsule()
                    .fill(PillieTheme.sage)
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                Text("Edit Schedule")
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Method")
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    Picker("Method", selection: $selectedMethod) {
                        ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedMethod == .pill {
                        Text("Pill Regimen")
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
                                            Text(regimen.title)
                                                .font(.pillieBodyBold())
                                                .foregroundStyle(PillieTheme.textPrimary)
                                            Text(regimen.scheduleSubtitle)
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
                                customInputCard(title: "Active Days", text: $customActiveDaysText)
                                customInputCard(title: "Break Days", text: $customBreakDaysText)
                            }
                        }
                    } else {
                        Text("SCHEDULE")
                            .font(.pillieCaptionMedium())
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(2)

                        Text(selectedMethod == .patch
                             ? "Patch reminders happen on cycle day 1, 8, and 15. Week 4 is off."
                             : "Ring reminders: day 1 insert, days 2-21 ring inserted, days 22-27 ring-free, day 28 reinsert.")
                            .font(.pillieBody())
                            .foregroundStyle(PillieTheme.textPrimary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PillieTheme.cardWhite)
                            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
                            )
                    }

                    Text("CURRENT CYCLE DAY")
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day \(selectedCycleDay) of \(cycleLength)")
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)

                        Stepper(value: $selectedCycleDay, in: 1...max(1, cycleLength)) {
                            Text("Adjust to your current day")
                                .font(.pillieBody())
                                .foregroundStyle(PillieTheme.textMuted)
                        }

                        Text("Days before your selected day will be marked as taken.")
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
                    Text("Save")
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.pillieSecondary)
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 20)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .alert("Reset Tracking Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset & Save", role: .destructive) {
                store.resetAndStartFresh(
                    method: selectedMethod,
                    regimen: selectedMethod == .pill ? selectedRegimen : .twentyOneSeven,
                    customActiveDays: selectedMethod == .pill && selectedRegimen == .custom ? customActiveDays : nil,
                    customBreakDays: selectedMethod == .pill && selectedRegimen == .custom ? customBreakDays : nil,
                    cycleDay: min(max(1, selectedCycleDay), cycleLength)
                )
                dismiss()
            }
        } message: {
            Text("Changing your schedule will reset all tracking history. You'll start at day \(selectedCycleDay). This cannot be undone.")
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

// MARK: - Reminder Time Editor

private struct ReminderTimeEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedPeriod: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text("Change Reminder Time")
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            HStack(spacing: 0) {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()

                Text(":")
                    .font(.pillieHeadline())
                    .foregroundStyle(PillieTheme.textPrimary)

                Picker("Minute", selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()

                Picker("Period", selection: $selectedPeriod) {
                    Text("AM").tag(0)
                    Text("PM").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()
            }

            Button {
                saveAndReschedule()
                dismiss()
            } label: {
                Text("Save")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear { seedFromStore() }
    }

    private func seedFromStore() {
        let selection = ReminderTimeConverter.toTwelveHour(
            hour24: store.reminderHour,
            minute: store.reminderMinute
        )
        selectedHour = selection.hour
        selectedMinute = selection.minute
        selectedPeriod = selection.period
    }

    private func saveAndReschedule() {
        let selection = ReminderTimeConverter.toTwentyFourHour(
            hour: selectedHour,
            minute: selectedMinute,
            period: selectedPeriod
        )
        store.reminderHour = selection.hour
        store.reminderMinute = selection.minute
        NotificationManager.shared.requestReschedule(from: store, reason: "settings-reminder-time")
    }
}

// MARK: - Auto Reminder Interval Editor

private struct AutoReminderIntervalEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedInterval: Int = 10

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text("Auto-Reminder Interval")
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            VStack(spacing: 16) {
                ForEach(PillStore.autoReminderIntervalOptions, id: \.self) { option in
                    Button {
                        selectedInterval = option
                    } label: {
                        HStack {
                            Text("\(option) minutes")
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedInterval == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedInterval == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                store.autoReminderIntervalMinutes = selectedInterval
                NotificationManager.shared.requestReschedule(from: store, reason: "settings-auto-interval")
                dismiss()
            } label: {
                Text("Save")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            selectedInterval = store.autoReminderIntervalMinutes
        }
    }
}

// MARK: - Refill Reminder Threshold Editor

private struct RefillReminderThresholdEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedThreshold: Int = 5

    private var isPatchMethod: Bool {
        store.pack.method == .patch
    }

    private var editorTitle: String {
        isPatchMethod ? "Restock Reminder" : "Refill Reminder"
    }

    private var thresholdOptions: [Int] {
        isPatchMethod ? PillStore.patchRestockReminderThresholdOptions : PillStore.refillReminderThresholdOptions
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text(editorTitle)
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            VStack(spacing: 16) {
                ForEach(thresholdOptions, id: \.self) { option in
                    Button {
                        selectedThreshold = option
                    } label: {
                        HStack {
                            Text(thresholdLabel(for: option))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedThreshold == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedThreshold == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                if isPatchMethod {
                    store.patchRestockReminderThresholdPatches = selectedThreshold
                } else {
                    store.refillReminderThresholdDays = selectedThreshold
                }
                NotificationManager.shared.requestReschedule(from: store, reason: "settings-supply-threshold")
                dismiss()
            } label: {
                Text("Save")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            selectedThreshold = isPatchMethod
                ? store.patchRestockReminderThresholdPatches
                : store.refillReminderThresholdDays
        }
    }

    private func thresholdLabel(for option: Int) -> String {
        if isPatchMethod {
            return option == 1 ? "1 patch left" : "\(option) patches left"
        }
        return "\(option) days before end"
    }
}

// MARK: - Cycle Day Editor

private struct CycleDayEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCycleDay: Int = 1

    private var cycleLength: Int {
        max(1, store.pack.cycleLength)
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text("Current Cycle Day")
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text("Day \(selectedCycleDay) of \(cycleLength)")
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.textPrimary)

            Stepper(
                value: $selectedCycleDay,
                in: 1...cycleLength
            ) {
                Text("Adjust current day")
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.horizontal, 20)

            Text("Days before your selected day will be marked as taken. No days will be marked as missed.")
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                store.updateCycleDay(selectedCycleDay)
                dismiss()
            } label: {
                Text("Save")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            selectedCycleDay = store.currentDayIndex + 1
        }
    }
}

#Preview {
    SettingsView()
        .environment(PillStore.previewStore())
}
