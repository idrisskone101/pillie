//
//  MethodPickerView.swift
//  Pillie
//

import SwiftUI

struct MethodPickerView: View {
    @State private var selectedMethod: ContraceptiveMethod = .pill
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: (ContraceptiveMethod) -> Void

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
            progress: 0.625,
            trailingLabel: nil,
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("What's your ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("method?")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("We'll customize your schedule.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 12) {
            ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                methodCard(method)
            }
        }
    }

    private func methodCard(_ method: ContraceptiveMethod) -> some View {
        let isSelected = selectedMethod == method

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedMethod = method
            }
        } label: {
            HStack(spacing: 16) {
                // Emoji icon
                Text(method.emoji)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(PillieTheme.sage.opacity(0.5))
                    )

                // Title + subtitle
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(method.title)
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)

                        if method == .pill && isSelected {
                            Text("popular!")
                                .font(.pillieHandwriting(size: 16).italic())
                                .foregroundStyle(PillieTheme.coral)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }

                    Text(method.subtitle)
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                }

                Spacer()

                // Radio circle
                Circle()
                    .stroke(isSelected ? PillieTheme.coral : PillieTheme.sage, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(PillieTheme.coral)
                                .frame(width: 12, height: 12)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(isSelected ? PillieTheme.coral.opacity(0.08) : PillieTheme.cardWhite)
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
            onContinue(selectedMethod)
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
    }
}

#Preview {
    MethodPickerView(
        onBack: {},
        onContinue: { _ in }
    )
}
