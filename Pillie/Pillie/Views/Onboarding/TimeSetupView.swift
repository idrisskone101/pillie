//
//  TimeSetupView.swift
//  Pillie
//

import SwiftUI

struct TimeSetupView: View {
    @Environment(PillStore.self) private var store

    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedPeriod: Int = 0 // 0 = AM, 1 = PM
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        timePickerCard
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        handwritingNote
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
        OnboardingStepHeader(
            appeared: animateIn,
            progress: 0.875,
            trailingLabel: nil,
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("When do you ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("take it?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Consistency is key. We'll help you stick to it.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Time Picker Card

    private var timePickerCard: some View {
        VStack(spacing: 20) {
            Text("DAILY REMINDER")
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

                // AM/PM picker
                Picker("Period", selection: $selectedPeriod) {
                    Text("AM").tag(0)
                    Text("PM").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 150)
                .clipped()
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

    // MARK: - Handwriting Note

    private var handwritingNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .foregroundStyle(PillieTheme.coral)
                .font(.system(size: 14))

            Text("Don't worry, you can change this later!")
                .font(.pillieHandwriting())
                .foregroundStyle(PillieTheme.textMuted)
        }
        .rotationEffect(.degrees(-2))
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            saveTimeToStore()
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                Text("Set Reminder")
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

    private func saveTimeToStore() {
        let selection = ReminderTimeConverter.toTwentyFourHour(
            hour: selectedHour,
            minute: selectedMinute,
            period: selectedPeriod
        )
        store.reminderHour = selection.hour
        store.reminderMinute = selection.minute

        NotificationManager.shared.requestAuthorization()
        NotificationManager.shared.requestReschedule(from: store, reason: "onboarding-reminder-time")
    }
}

#Preview {
    TimeSetupView(
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
