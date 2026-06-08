//
//  AcquisitionSourceView.swift
//  Pillie
//

import SwiftUI

struct AcquisitionSourceView: View {
    @State private var selected: AcquisitionSource?
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (AcquisitionSource) -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        cardList
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
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

    private var header: some View {
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: PersonalizationOnboardingProgress.fraction(for: 4),
            badge: PersonalizationOnboardingProgress.badge(for: 4),
            onBack: onBack
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("How did you ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("find Pillie?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillie(30, weight: .black))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("Optional, and only used as a broad product signal.")
                .font(.pillie(16, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.leading)
                .lineSpacing(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardList: some View {
        VStack(spacing: 9) {
            ForEach(AcquisitionSource.allCases, id: \.self) { source in
                sourceCard(source)
            }
        }
    }

    private func sourceCard(_ source: AcquisitionSource) -> some View {
        let isSelected = selected == source

        return PersonalizationOptionRow(
            title: source.title,
            subtitle: nil,
            symbolName: iconName(for: source),
            symbolTint: iconTint(for: source),
            isSelected: isSelected,
            selectionStyle: .checkmark,
            minHeight: 52,
            verticalPadding: 6
        ) {
            selected = source
        }
        .accessibilityIdentifier("acquisitionSource.\(source.rawValue)")
    }

    private var footer: some View {
        PersonalizationFooter(
            isEnabled: selected != nil,
            helperText: nil,
            skipTitle: "Not Now",
            onSkip: onSkip
        ) {
                if let selected {
                    onContinue(selected)
                }
        }
        .accessibilityIdentifier("acquisitionSource.continue")
    }

    private func iconName(for source: AcquisitionSource) -> String {
        switch source {
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .appStoreSearch: return "bag"
        case .friendOrWordOfMouth: return "person.2"
        case .reddit: return "bubble.left.and.bubble.right"
        case .other: return "ellipsis"
        }
    }

    private func iconTint(for source: AcquisitionSource) -> Color {
        switch source {
        case .tiktok, .instagram, .reddit, .other: return PillieTheme.textMuted.opacity(0.7)
        case .appStoreSearch: return PillieTheme.textPrimary
        case .friendOrWordOfMouth: return PillieTheme.textMuted.opacity(0.65)
        }
    }
}

#Preview {
    AcquisitionSourceView(
        onBack: {},
        onContinue: { _ in },
        onSkip: {}
    )
}
