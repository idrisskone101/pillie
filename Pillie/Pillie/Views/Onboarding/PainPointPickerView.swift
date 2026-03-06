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
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        cardList
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
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
            progress: 0.125,
            trailingLabel: "1/4",
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("What's your biggest ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("hurdle?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Select all that apply.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 12) {
            ForEach(PainPoint.allCases, id: \.self) { painPoint in
                painPointCard(painPoint)
            }
        }
    }

    private func painPointCard(_ painPoint: PainPoint) -> some View {
        let isSelected = selected.contains(painPoint)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isSelected {
                    selected.remove(painPoint)
                } else {
                    selected.insert(painPoint)
                }
            }
        } label: {
            HStack(spacing: 16) {
                // Emoji icon
                Text(painPoint.emoji)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(PillieTheme.sage.opacity(0.5))
                    )

                // Title + subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(painPoint.title)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)

                    Text(painPoint.subtitle)
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                }

                Spacer()

                // Checkbox
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? PillieTheme.coral : PillieTheme.sage, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? PillieTheme.coral : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(isSelected ? PillieTheme.coral.opacity(0.05) : PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(isSelected ? PillieTheme.coral : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? PillieTheme.coral.opacity(0.15) : PillieTheme.cardShadow,
                radius: isSelected ? 12 : PillieTheme.cardShadowRadius,
                y: isSelected ? 4 : PillieTheme.cardShadowY
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            onContinue(selected)
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .disabled(selected.isEmpty)
        .opacity(selected.isEmpty ? 0.5 : 1.0)
    }
}

#Preview {
    PainPointPickerView(
        onBack: {},
        onContinue: { _ in }
    )
}
