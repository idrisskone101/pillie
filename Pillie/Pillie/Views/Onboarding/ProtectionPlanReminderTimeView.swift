//
//  ProtectionPlanReminderTimeView.swift
//  Pillie
//
//  Reminder Time — "the golden hour" (issue #77, Superdesign draft ec61e147). The
//  user sets their Due Action Time through the existing production reminder model
//  (`PillStore` hour/minute + `ScheduleCriticalSettingChange`), so nothing about
//  scheduling changes. The plan card completes here as the finale of the build, and
//  the caption is method-aware and honest that app blocking is configured later.
//

import SwiftUI

struct ProtectionPlanReminderTimeView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(PillStore.self) private var store

    private let content = ProtectionPlanReminderTimeContent.default
    private let onboardingTelemetry = OnboardingTelemetry()

    @State private var selectedHour = 8
    @State private var selectedMinute = 0
    @State private var selectedPeriod = 0 // 0 = AM, 1 = PM
    @State private var appeared = false
    @State private var isCommitting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    private var liveTimeText: String {
        ProtectionPlanRoutineSummary.clockText(
            hour12: selectedHour,
            minute: selectedMinute,
            isPM: selectedPeriod == 1
        )
    }

    private var scheduleSummaryText: String {
        let pack = store.pack
        switch pack.method {
        case .pill:
            return "\(pack.pillRegimen.routineDisplayName) · \(pack.pillRegimen.scheduleSubtitle)"
        case .patch:
            return "Weekly patch · 28-day cycle"
        case .ring:
            return "Monthly ring · 28-day cycle"
        }
    }

    private var summary: ProtectionPlanRoutineSummary {
        ProtectionPlanRoutineSummary(
            method: store.contraceptiveMethod,
            scheduleSummary: scheduleSummaryText,
            cycleDay: store.pack.cycleDayIndex(on: store.today) + 1,
            reminderTimeText: liveTimeText
        )
    }

    private var protectionLine: String {
        let language = MethodActionLanguage(method: store.contraceptiveMethod)
        return "Distracting apps lock from \(liveTimeText) until you \(language.actionPhrase)."
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: content.primaryCTA,
            primaryIcon: "bell.fill",
            animatesPrimaryIcon: false,
            isPrimaryEnabled: true,
            isPrimaryLoading: isCommitting,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ProtectionPlanQuestionHeader(title: content.title, subtitle: content.subtitle)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger1)

                pickerCard
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

                ProtectionPlanRoutineCard(summary: summary, animationsEnabled: animationsEnabled)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger3)

                Text(protectionLine)
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger4)
            }
        }
        .onAppear {
            seedFromStore()
            appeared = true
        }
    }

    // MARK: - Picker

    private var pickerCard: some View {
        VStack(spacing: 18) {
            Text(content.pickerLabel.uppercased())
                .font(.pillie(11, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(PillieTheme.coral)

            HStack(spacing: 0) {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.hourLabel)
                .accessibilityValue("\(selectedHour)")

                Text(":")
                    .font(.pillie(28, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Picker("Minute", selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.minuteLabel)
                .accessibilityValue(String(format: "%02d", selectedMinute))

                Picker("Period", selection: $selectedPeriod) {
                    Text("AM").tag(0)
                    Text("PM").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.periodLabel)
                .accessibilityValue(selectedPeriod == 0 ? "AM" : "PM")
            }

            HStack(spacing: 0) {
                quickToggle(title: "Morning", icon: "sun.max.fill", isSelected: selectedPeriod == 0) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedHour = 8
                        selectedMinute = 0
                        selectedPeriod = 0
                    }
                }
                quickToggle(title: "Evening", icon: "moon.fill", isSelected: selectedPeriod == 1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedHour = 8
                        selectedMinute = 0
                        selectedPeriod = 1
                    }
                }
            }
            .padding(4)
            .background(PillieTheme.sage, in: Capsule())
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .overlay { RoundedRectangle(cornerRadius: PillieTheme.cardRadius).stroke(Color.black.opacity(0.06), lineWidth: 1) }
    }

    private func quickToggle(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(.pillie(15, weight: .semibold))
            }
            .foregroundStyle(isSelected ? PillieTheme.textPrimary : PillieTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Color.clear), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Commit + seeding

    /// Persists the chosen time, resolves notification authorization, and only
    /// then advances the flow — scheduling happens strictly after a grant, so a
    /// fresh install can never hit the code-2003 "Source is not authorized"
    /// storm (#196). The CTA shows a spinner and swallows re-taps while the iOS
    /// permission prompt is up.
    private func commit() {
        guard !isCommitting else { return }
        isCommitting = true
        let selection = ReminderTimeConverter.toTwentyFourHour(
            hour: selectedHour,
            minute: selectedMinute,
            period: selectedPeriod
        )
        OnboardingReminderCommit.live(store: store, telemetry: onboardingTelemetry)
            .run(hour: selection.hour, minute: selection.minute) {
                isCommitting = false
                onContinue()
            }
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
}

#Preview {
    ProtectionPlanReminderTimeView(
        progress: ProtectionPlanProgress(index: 13, total: 13),
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
