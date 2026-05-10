//
//  MethodDetailsView.swift
//  Pillie
//

import SwiftUI

struct MethodDetailsView: View {
    @Environment(PillStore.self) private var store

    @State private var selectedRegimen: PillPack.PillRegimenPreset = .twentyOneSeven
    @State private var customActiveDaysText = "21"
    @State private var customBreakDaysText = "7"
    @State private var cycleDay = 1
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (PillPack.PillRegimenPreset, Int?, Int?, Int) -> Void

    private var method: ContraceptiveMethod {
        store.contraceptiveMethod
    }

    private var customActiveDays: Int {
        let value = Int(customActiveDaysText) ?? 21
        return min(max(value, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
    }

    private var customBreakDays: Int {
        let value = Int(customBreakDaysText) ?? 7
        return min(max(value, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
    }

    private var cycleLength: Int {
        switch method {
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
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        if method == .pill {
                            regimenSection
                                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                        } else {
                            methodInfoSection
                                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                        }

                        cycleDaySection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                            .animation(.none, value: cycleDay)
                            .animation(.none, value: selectedRegimen)
                            .animation(.none, value: customActiveDaysText)
                            .animation(.none, value: customBreakDaysText)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            seedFromStore()
            animateIn = true
            guard performanceTier == .standard else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
        .onChange(of: selectedRegimen) { _, _ in
            clampCycleDay()
        }
        .onChange(of: customActiveDaysText) { _, _ in
            clampCycleDay()
        }
        .onChange(of: customBreakDaysText) { _, _ in
            clampCycleDay()
        }
    }

    // MARK: - Header

    private var header: some View {
        OnboardingStepHeader(
            appeared: animateIn,
            progress: 0.75,
            trailingLabel: "2/5",
            onBack: onBack
        )
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Let's set your")
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("schedule")
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.coral)
                .multilineTextAlignment(.center)

            Text("Choose your cycle setup so reminders match your method.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var regimenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PILL REGIMEN")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            VStack(spacing: 10) {
                ForEach(PillPack.PillRegimenPreset.allCases, id: \.rawValue) { regimen in
                    regimenCard(regimen)
                }
            }

            if selectedRegimen == .custom {
                customInputs
                    .padding(.top, 6)
            }
        }
    }

    private func regimenCard(_ regimen: PillPack.PillRegimenPreset) -> some View {
        let isSelected = selectedRegimen == regimen
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedRegimen = regimen
            }
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
                Circle()
                    .stroke(isSelected ? PillieTheme.coral : PillieTheme.sage, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(PillieTheme.coral)
                                .frame(width: 10, height: 10)
                        }
                    }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(isSelected ? PillieTheme.coral.opacity(0.08) : PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(isSelected ? PillieTheme.coral : PillieTheme.sageHalf, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customInputs: some View {
        HStack(spacing: 12) {
            customInputCard(title: "Active Days", text: $customActiveDaysText)
            customInputCard(title: "Break Days", text: $customBreakDaysText)
        }
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

    private var methodInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            Text(method == .patch
                 ? "Patch reminders: day 1 apply, days 8 and 15 change, day 22 remove, days 23-28 patch-free."
                 : "Ring reminders: day 1 insert, days 2-21 ring inserted, day 22 remove, days 23-28 ring-free.")
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
    }

    private var cycleDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT CYCLE DAY")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Day \(cycleDay) of \(cycleLength)")
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)

                Stepper(value: $cycleDay, in: 1...max(1, cycleLength)) {
                    Text("Adjust to your current day")
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                }
            }
            .padding(16)
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            onContinue(
                selectedRegimen,
                selectedRegimen == .custom ? customActiveDays : nil,
                selectedRegimen == .custom ? customBreakDays : nil,
                min(max(1, cycleDay), cycleLength)
            )
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
    }

    // MARK: - Helpers

    private func seedFromStore() {
        let activePack = store.pack
        if method == .pill && activePack.method == .pill {
            selectedRegimen = activePack.pillRegimen
            if selectedRegimen == .custom {
                customActiveDaysText = "\(activePack.customActiveDays ?? 21)"
                customBreakDaysText = "\(activePack.customBreakDays ?? 7)"
            }
        } else {
            selectedRegimen = .twentyOneSeven
            customActiveDaysText = "21"
            customBreakDaysText = "7"
        }
        if activePack.method == method {
            cycleDay = activePack.cycleDayIndex(on: store.today) + 1
        } else {
            cycleDay = 1
        }
        clampCycleDay()
    }

    private func clampCycleDay() {
        withAnimation(.none) {
            cycleDay = min(max(1, cycleDay), max(1, cycleLength))
        }
    }
}

#Preview {
    MethodDetailsView(
        onBack: {},
        onContinue: { _, _, _, _ in }
    )
    .environment(PillStore.previewStore())
}
