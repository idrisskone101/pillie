//
//  AnalyticsConsentView.swift
//  Pillie
//

import SwiftUI

struct AnalyticsConsentView: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                VStack(spacing: 28) {
                    iconStack
                        .offset(y: animateIn ? 0 : 12)
                        .opacity(animateIn ? 1 : 0)
                        .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1), value: animateIn)

                    VStack(spacing: 14) {
                        Text("Help make Pillie better")
                            .font(.pillieTitle())
                            .foregroundStyle(PillieTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Share anonymous app-flow data so we can improve onboarding, reminders, and Plus. No health details, pill schedule, or personal notes are collected.")
                            .font(.pillieBody())
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .offset(y: animateIn ? 0 : 12)
                    .opacity(animateIn ? 1 : 0)
                    .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger2), value: animateIn)

                    privacyPoints
                        .offset(y: animateIn ? 0 : 12)
                        .opacity(animateIn ? 1 : 0)
                        .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger3), value: animateIn)
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)

                Spacer(minLength: 28)

                VStack(spacing: 12) {
                    Button(action: onAllow) {
                        Text("Allow Analytics")
                    }
                    .buttonStyle(.pillieDark)
                    .accessibilityIdentifier("allowAnalyticsButton")

                    Button(action: onDecline) {
                        Text("Not Now")
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(PillieTheme.textMuted.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: PillieTheme.cardShadow, radius: 12, y: 6)
                    .accessibilityIdentifier("declineAnalyticsButton")
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
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

    private var iconStack: some View {
        ZStack {
            Circle()
                .fill(PillieTheme.lavender.opacity(0.55))
                .frame(width: 136, height: 136)
                .shadow(color: PillieTheme.lavender.opacity(0.35), radius: 20, y: 12)

            Circle()
                .fill(Color.white.opacity(0.84))
                .frame(width: 104, height: 104)
                .overlay(
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(PillieTheme.sage)
                        .background(Color.white, in: Circle())
                        .offset(x: 8, y: -6)
                }
        }
        .accessibilityHidden(true)
    }

    private var privacyPoints: some View {
        VStack(alignment: .leading, spacing: 12) {
            consentPoint(icon: "lock.fill", text: "Off until you choose to allow it.")
            consentPoint(icon: "arrow.uturn.backward", text: "You can change this later in Settings.")
            consentPoint(icon: "heart.text.square.fill", text: "Never includes personal health details.")
        }
        .padding(18)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func consentPoint(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 24, height: 24)
                .background(PillieTheme.coral.opacity(0.12), in: Circle())

            Text(text)
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AnalyticsConsentView(onAllow: {}, onDecline: {})
}
