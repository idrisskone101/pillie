//
//  PainPointPickerView.swift
//  Pillie
//

import SwiftUI

struct PainPointPickerView: View {
    @State private var selected: Set<PainPoint> = []
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (Set<PainPoint>) -> Void

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
            progress: PersonalizationOnboardingProgress.fraction(for: 1),
            badge: PersonalizationOnboardingProgress.badge(for: 1),
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            (Text("What's your biggest ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("hurdle?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillie(38, weight: .black))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("Select all that apply.")
                .font(.pillie(19, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 10) {
            ForEach(PainPoint.allCases, id: \.self) { painPoint in
                painPointCard(painPoint)
            }
        }
    }

    private func painPointCard(_ painPoint: PainPoint) -> some View {
        let isSelected = selected.contains(painPoint)

        return PersonalizationOptionRow(
            title: painPoint.title,
            subtitle: nil,
            symbolName: iconName(for: painPoint),
            symbolTint: iconTint(for: painPoint),
            isSelected: isSelected,
            selectionStyle: .checkbox
        ) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                if isSelected {
                    selected.remove(painPoint)
                } else {
                    selected.insert(painPoint)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        PersonalizationFooter(
            isEnabled: !selected.isEmpty,
            helperText: "Select at least one to continue"
        ) {
            onContinue(selected)
        }
    }

    private func iconName(for painPoint: PainPoint) -> String {
        switch painPoint {
        case .forgetful: return "brain.head.profile"
        case .chaoticSchedule: return "calendar"
        case .phoneDistractions: return "iphone"
        case .noRoutine: return "arrow.triangle.2.circlepath"
        }
    }

    private func iconTint(for painPoint: PainPoint) -> Color {
        switch painPoint {
        case .forgetful: return PillieTheme.coral
        case .chaoticSchedule: return Color(hex: "9AAE9D")
        case .phoneDistractions: return Color(hex: "AAA5D6")
        case .noRoutine: return PillieTheme.textMuted
        }
    }
}

#Preview {
    PainPointPickerView(
        onBack: {},
        onContinue: { _ in }
    )
}
