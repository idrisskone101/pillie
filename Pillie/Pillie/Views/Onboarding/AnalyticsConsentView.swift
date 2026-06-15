//
//  AnalyticsConsentView.swift
//  Pillie
//

import SwiftUI

struct AnalyticsConsentView: View {
    let onBack: () -> Void
    let onAllow: () -> Void
    let onDecline: () -> Void

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current
    private let shell = OnboardingFlow.shellState(for: .analyticsConsent)!

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .offset(y: animateIn ? 0 : -8)
                    .opacity(animateIn ? 1 : 0)
                    .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1), value: animateIn)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                    iconStack
                        .offset(y: animateIn ? 0 : 12)
                        .opacity(animateIn ? 1 : 0)
                        .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger2), value: animateIn)

                    VStack(spacing: 10) {
                        Text("Better every day")
                            .font(.pillieHandwriting(size: 26))
                            .foregroundStyle(PillieTheme.textMuted.opacity(0.65))
                            .rotationEffect(.degrees(-3))

                        Text("Help improve Pillie?")
                            .font(.pillieHeadline())
                            .foregroundStyle(PillieTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Share privacy-safe product analytics so we can see which screens work and where setup gets confusing. We never send your contraception method, reminder time, history, app-blocking choices, or anything you type.")
                            .font(.pillie(14, weight: .regular))
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .offset(y: animateIn ? 0 : 12)
                    .opacity(animateIn ? 1 : 0)
                    .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger3), value: animateIn)

                    privacyPoints
                        .offset(y: animateIn ? 0 : 12)
                        .opacity(animateIn ? 1 : 0)
                        .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger4), value: animateIn)
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }

                VStack(spacing: 12) {
                    Button(action: onAllow) {
                        Text(shell.primaryActionTitle)
                    }
                    .buttonStyle(.pillieDark)
                    .disabled(!shell.isPrimaryActionEnabled)
                    .accessibilityIdentifier("allowAnalyticsButton")

                    Button(action: onDecline) {
                        Text(shell.secondaryActionTitle ?? "Not Now")
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .accessibilityIdentifier("declineAnalyticsButton")
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .background(
                    LinearGradient(
                        colors: [
                            PillieTheme.bg.opacity(0),
                            PillieTheme.bg.opacity(0.96),
                            PillieTheme.bg
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
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
        HStack(spacing: 14) {
            if shell.showsBackButton {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.9), in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(PillieTheme.textMuted.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("analyticsConsentBackButton")
            }

            ProgressView(value: shell.progressFraction)
                .progressViewStyle(.linear)
                .tint(PillieTheme.coral)
                .frame(height: 8)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
                .clipShape(Capsule())

            Text(shell.progressLabel)
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.coral)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Onboarding progress, \(shell.progressLabel)")
    }

    private var iconStack: some View {
        ZStack {
            Circle()
                .fill(PillieTheme.lavender.opacity(0.55))
                .frame(width: 96, height: 96)
                .shadow(color: PillieTheme.lavender.opacity(0.35), radius: 20, y: 12)

            Circle()
                .fill(Color.white.opacity(0.84))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PillieTheme.sage)
                        .background(Color.white, in: Circle())
                        .offset(x: 8, y: -6)
                }
        }
        .accessibilityHidden(true)
    }

    private var privacyPoints: some View {
        VStack(alignment: .leading, spacing: 6) {
            consentPoint(
                icon: "checkmark.shield.fill",
                title: "Strict privacy",
                text: "Product Analytics Telemetry stays off until you allow it."
            )
            consentPoint(
                icon: "chart.bar.xaxis",
                title: "Setup health",
                text: "We only learn which screens work and where setup gets confusing."
            )
            consentPoint(
                icon: "eye.slash.fill",
                title: "No sensitive answers",
                text: "No method, reminder time, history, app choices, or typed text."
            )
        }
        .padding(12)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func consentPoint(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 30, height: 30)
                .background(PillieTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.pillie(13, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(text)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(2)
    }
}

#Preview {
    AnalyticsConsentView(onBack: {}, onAllow: {}, onDecline: {})
}
