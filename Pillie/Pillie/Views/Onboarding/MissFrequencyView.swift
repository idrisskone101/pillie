//
//  MissFrequencyView.swift
//  Pillie
//

import SwiftUI

struct MissFrequencyView: View {
    @State private var selected: MissFrequency?
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (MissFrequency) -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        cardList
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 12)
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
            progress: PersonalizationOnboardingProgress.fraction(for: 3),
            badge: PersonalizationOnboardingProgress.badge(for: 3),
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            (Text("How often do you ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("miss?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillie(36, weight: .black))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("No judgment — we're here to help.")
                .font(.pillie(19, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 10) {
            ForEach(MissFrequency.allCases, id: \.self) { frequency in
                frequencyCard(frequency)
            }
        }
    }

    private func frequencyCard(_ frequency: MissFrequency) -> some View {
        let isSelected = selected == frequency

        return PersonalizationOptionRow(
            title: frequency.title,
            subtitle: frequency.subtitle,
            symbolName: "",
            symbolTint: .clear,
            isSelected: isSelected,
            selectionStyle: .radio,
            minHeight: 70,
            verticalPadding: 9
        ) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selected = frequency
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        PersonalizationFooter(
            isEnabled: selected != nil,
            helperText: "No shame here. We'll shape reminders around real life."
        ) {
            if let selected {
                onContinue(selected)
            }
        }
    }
}

#Preview {
    MissFrequencyView(
        onBack: {},
        onContinue: { _ in }
    )
}
