//
//  TimeSetupView.swift
//  Pillie
//

import SwiftUI

enum ReminderTimePickerAccessibility {
    static let hourLabel = "Reminder hour"
    static let minuteLabel = "Reminder minute"
    static let periodLabel = "Reminder period"
}

struct TimeSetupView: View {
    @Environment(PillStore.self) private var store

    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedPeriod: Int = 0 // 0 = AM, 1 = PM
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current
    private let onboardingTelemetry = OnboardingTelemetry()

    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        timePickerCard
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        settingsNote
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
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
    }

    // MARK: - Header

    private var header: some View {
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: PersonalizationOnboardingProgress.fraction(for: 7),
            badge: PersonalizationOnboardingProgress.badge(for: 7),
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("When do you ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("want reminders?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Pick the time Pillie should use for due-action reminders.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Time Picker Card

    private var timePickerCard: some View {
        VStack(spacing: 20) {
            Text("DUE ACTION REMINDER")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.coral)
                .tracking(2)

            HStack(spacing: 0) {
                // Hour picker
                Picker("Hour", selection: $selectedHour) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)")
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.hourLabel)
                .accessibilityValue("\(selectedHour)")

                Text(":")
                    .font(.pillieHeadline())
                    .foregroundStyle(PillieTheme.textPrimary)

                // Minute picker
                Picker("Minute", selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute))
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.minuteLabel)
                .accessibilityValue(String(format: "%02d", selectedMinute))

                // AM/PM picker
                Picker("Period", selection: $selectedPeriod) {
                    Text("AM").tag(0)
                    Text("PM").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReminderTimePickerAccessibility.periodLabel)
                .accessibilityValue(selectedPeriod == 0 ? "AM" : "PM")
            }

            // Morning / Evening toggle
            HStack(spacing: 0) {
                quickToggleButton(title: "Morning", icon: "sun.max.fill", isSelected: selectedPeriod == 0) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedHour = 8
                        selectedMinute = 0
                        selectedPeriod = 0
                    }
                }

                quickToggleButton(title: "Evening", icon: "moon.fill", isSelected: selectedPeriod == 1) {
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
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .shadow(
            color: PillieTheme.cardShadow,
            radius: PillieTheme.cardShadowRadius,
            y: PillieTheme.cardShadowY
        )
    }

    private func quickToggleButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.pillieBodySemibold())
            }
            .foregroundStyle(isSelected ? PillieTheme.textPrimary : PillieTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                isSelected ? AnyShapeStyle(PillieTheme.cardWhite) : AnyShapeStyle(Color.clear),
                in: Capsule()
            )
            .shadow(color: isSelected ? PillieTheme.cardShadow : .clear, radius: isSelected ? 4 : 0, y: isSelected ? 2 : 0)
        }
        .buttonStyle(.plain)
    }

    private var settingsNote: some View {
        Text("You can change this anytime in Settings.")
            .font(.pillieCaptionMedium())
            .foregroundStyle(PillieTheme.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            saveReminderTime()
            onContinue()
            DispatchQueue.main.async {
                onboardingTelemetry.notificationPermissionRequested()
                NotificationManager.shared.requestAuthorization()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                Text("Set Reminder Time")
            }
        }
        .buttonStyle(.pillieDark)
    }

    // MARK: - Helpers

    private func seedFromStore() {
        let selection = ReminderTimeConverter.toTwelveHour(
            hour24: store.reminderHour,
            minute: store.reminderMinute
        )
        selectedHour = selection.hour
        selectedMinute = selection.minute
        selectedPeriod = selection.period
    }

    private func saveReminderTime() {
        let selection = ReminderTimeConverter.toTwentyFourHour(
            hour: selectedHour,
            minute: selectedMinute,
            period: selectedPeriod
        )
        ScheduleCriticalSettingChange.saveOnboardingReminderTime(
            store: store,
            hour: selection.hour,
            minute: selection.minute
        )
    }
}

#Preview {
    TimeSetupView(
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
