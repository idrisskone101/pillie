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

    @State private var selectedTime = Date()
    @State private var appeared = false
    @State private var isCommitting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    private var liveTimeText: String {
        selectedTime.formatted(date: .omitted, time: .shortened)
    }

    private var scheduleSummaryText: String {
        let pack = store.pack
        switch pack.method {
        case .pill:
            return pack.pillRegimen.localizedScheduleSummary()
        case .patch:
            return pack.method.routineDescriptor
        case .ring:
            return pack.method.routineDescriptor
        }
    }

    private var summary: ProtectionPlanRoutineSummary {
        ProtectionPlanRoutineSummary(
            method: store.contraceptiveMethod,
            scheduleSummary: scheduleSummaryText,
            cycleDay: store.pack.cycleDayIndex(on: store.today) + 1,
            reminderTimeText: liveTimeText,
            locale: .current
        )
    }

    private var protectionLine: String {
        PillieLocalization.string("onboarding.blocking_setup.subtitle")
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

            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .frame(height: 150)
            .clipped()
            .accessibilityLabel(
                PillieLocalization.formatted(
                    "onboarding.reminder_time.accessibility",
                    arguments: liveTimeText
                )
            )

            HStack(spacing: 0) {
                quickToggle(title: PillieLocalization.string("onboarding.reminder_time.morning"), icon: "sun.max.fill", isSelected: selectedHour < 12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTime = date(hour: 8, minute: 0)
                    }
                }
                quickToggle(title: PillieLocalization.string("onboarding.reminder_time.evening"), icon: "moon.fill", isSelected: selectedHour >= 12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTime = date(hour: 20, minute: 0)
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
        let selection = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        OnboardingReminderCommit.live(store: store, telemetry: onboardingTelemetry)
            .run(hour: selection.hour ?? 8, minute: selection.minute ?? 0) {
                isCommitting = false
                onContinue()
            }
    }

    private func seedFromStore() {
        selectedTime = date(hour: store.reminderHour, minute: store.reminderMinute)
    }

    private var selectedHour: Int {
        Calendar.current.component(.hour, from: selectedTime)
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: selectedTime
        ) ?? selectedTime
    }
}

#Preview {
    ProtectionPlanReminderTimeView(
        progress: ProtectionPlanProgressIndex.progress(for: .reminderTime),
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
