//
//  FreePlanView.swift
//  Pillie
//

import SwiftUI

struct FreePlanView: View {
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

                        featureCards
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        valueProposition

                        footerCaption
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
            progress: 0.25,
            trailingLabel: "2/4",
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("The Free Plan. ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("Forever Simple.")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Everything you need to stay on track.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 12) {
            featureCard(
                icon: "bell.fill",
                title: "Daily Reminders",
                subtitle: "Never miss your pill again"
            )

            featureCard(
                icon: "chart.bar.fill",
                title: "Track Your History",
                subtitle: "See your consistency over time"
            )
        }
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(PillieTheme.sage.opacity(0.5))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(subtitle)
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
            }

            Spacer()
        }
        .padding(16)
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

    // MARK: - Value Proposition

    private var valueProposition: some View {
        VStack(spacing: 12) {
            Text("Immediate peace of mind")
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text("No setup fees, no hidden costs.")
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
        }
        .padding(.top, 8)
    }

    // MARK: - Footer Caption

    private var footerCaption: some View {
        Text("Step 2 of 4 \u{00B7} You can upgrade any time")
            .font(.pillie(13, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            onContinue()
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
    FreePlanView(onBack: {}, onContinue: {})
}
