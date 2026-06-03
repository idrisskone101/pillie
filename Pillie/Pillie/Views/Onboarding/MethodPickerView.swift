//
//  MethodPickerView.swift
//  Pillie
//

import SwiftUI

struct MethodPickerView: View {
    @Environment(PillStore.self) private var store

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
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

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
            selectedMethod = store.contraceptiveMethod
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
            progress: PersonalizationOnboardingProgress.fraction(for: 5),
            badge: PersonalizationOnboardingProgress.badge(for: 5),
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

            Text("We'll tailor your reminders to match how your contraception works.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        VStack(spacing: 12) {
            ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                methodCard(method)
            }

            Text("Other methods coming soon to Pillie")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted.opacity(0.75))
                .padding(.top, 4)
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
                Image(systemName: methodSymbol(method))
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(isSelected ? PillieTheme.coral : PillieTheme.textMuted)
                    .frame(width: 58, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSelected ? PillieTheme.cardWhite : methodIconBackground(method))
                    )

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

                ZStack {
                    Circle()
                        .stroke(isSelected ? PillieTheme.coral : PillieTheme.sage, lineWidth: 2)
                        .background(Circle().fill(isSelected ? PillieTheme.coral : Color.clear))

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                    .frame(width: 24, height: 24)
            }
            .padding(18)
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
        .accessibilityIdentifier("onboarding-method-\(method.rawValue)")
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
        .accessibilityIdentifier("onboarding-method-continue")
    }

    private func methodSymbol(_ method: ContraceptiveMethod) -> String {
        switch method {
        case .pill:
            return "pills.fill"
        case .patch:
            return "square.on.square"
        case .ring:
            return "circle"
        }
    }

    private func methodIconBackground(_ method: ContraceptiveMethod) -> Color {
        switch method {
        case .pill:
            return PillieTheme.coral.opacity(0.12)
        case .patch:
            return PillieTheme.lavender.opacity(0.7)
        case .ring:
            return PillieTheme.sage.opacity(0.7)
        }
    }
}

#Preview {
    MethodPickerView(
        onBack: {},
        onContinue: { _ in }
    )
}
