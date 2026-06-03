//
//  GoalPickerView.swift
//  Pillie
//

import SwiftUI

struct GoalPickerView: View {
    @State private var selected: PersonalGoal?
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (PersonalGoal) -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        cardList
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 38)
                    .padding(.bottom, 14)
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
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
            progress: PersonalizationOnboardingProgress.fraction(for: 2),
            badge: PersonalizationOnboardingProgress.badge(for: 2),
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            (Text("What's your ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("goal?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillie(38, weight: .black))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("This helps us personalize your experience.")
                .font(.pillie(19, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 10) {
            ForEach(PersonalGoal.allCases, id: \.self) { goal in
                goalCard(goal)
            }
        }
    }

    private func goalCard(_ goal: PersonalGoal) -> some View {
        let isSelected = selected == goal

        return PersonalizationOptionRow(
            title: goal.title,
            subtitle: nil,
            symbolName: iconName(for: goal),
            symbolTint: iconTint(for: goal),
            isSelected: isSelected,
            selectionStyle: .radio
        ) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selected = goal
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        PersonalizationFooter(
            isEnabled: selected != nil,
            helperText: "This helps personalize your routine. Pillie is not medical advice."
        ) {
            if let selected {
                onContinue(selected)
            }
        }
    }

    private func iconName(for goal: PersonalGoal) -> String {
        switch goal {
        case .stayProtected: return "shield.checkered"
        case .hormonalBalance: return "sparkles"
        case .peaceOfMind: return "leaf"
        case .buildRoutine: return "arrow.triangle.2.circlepath"
        }
    }

    private func iconTint(for goal: PersonalGoal) -> Color {
        switch goal {
        case .stayProtected: return PillieTheme.coral
        case .hormonalBalance: return Color(hex: "9C94BA")
        case .peaceOfMind: return Color(hex: "94A894")
        case .buildRoutine: return PillieTheme.textMuted
        }
    }
}

#Preview {
    GoalPickerView(
        onBack: {},
        onContinue: { _ in }
    )
}
