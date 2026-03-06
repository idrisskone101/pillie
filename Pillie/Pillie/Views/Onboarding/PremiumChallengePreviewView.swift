//
//  PremiumChallengePreviewView.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PremiumChallengePreviewView: View {
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var shakeManager = ShakeDetectionManager(requiredShakes: 5)
    @State private var celebrating = false
    @State private var emojiOffset: CGFloat = 0
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

                        heroChallengeCard
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        comparisonTable
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        cancelCaption
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
            shakeManager.startDetecting()
            guard performanceTier == .standard else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
        .onDisappear {
            shakeManager.stopDetecting()
        }
        .onChange(of: shakeManager.shakeCount) { oldValue, newValue in
            guard newValue > oldValue else { return }
            bounceEmoji()
            fireShakeHaptic(count: newValue)

            if shakeManager.isComplete {
                celebrateAndReset()
            }
        }
    }

    // MARK: - Shake Helpers

    private func bounceEmoji() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            emojiOffset = -16
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                emojiOffset = 0
            }
        }
    }

    private func fireShakeHaptic(count: Int) {
        #if os(iOS)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch count {
        case 1: style = .light
        case 2: style = .medium
        default: style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private func celebrateAndReset() {
        shakeManager.stopDetecting()

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            celebrating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                celebrating = false
            }
            shakeManager.reset()
            shakeManager.startDetecting()
        }
    }

    // MARK: - Header

    private var header: some View {
        OnboardingStepHeader(
            appeared: animateIn,
            progress: 0.375,
            trailingLabel: "3/4",
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("Stop the distraction, ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("unlock your focus")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Premium features to build real habits.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    // MARK: - Hero Challenge Card (Live Demo)

    private var heroChallengeCard: some View {
        VStack(spacing: 16) {
            Text(celebrating ? "Nice!" : "Shake Your Phone")
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            // Progress ring + emoji
            ZStack {
                Circle()
                    .stroke(PillieTheme.sage, lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: shakeManager.progress)
                    .stroke(PillieTheme.coral, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: shakeManager.progress)

                Text("💊")
                    .font(.system(size: 40))
                    .offset(y: emojiOffset)
                    .scaleEffect(celebrating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: celebrating)
            }
            .scaleEffect(emojiOffset != 0 ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: emojiOffset)

            // Shake counter
            Text("\(shakeManager.shakeCount) / \(shakeManager.requiredShakes)")
                .font(.pillie(20, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: shakeManager.shakeCount)

            Text(celebrating ? "Try it again!" : "Shake to dismiss your reminder")
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)

            // Simulator tap-to-shake fallback
            #if targetEnvironment(simulator)
            Button {
                shakeManager.simulateShake()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tap to Simulate Shake")
                        .font(.pillie(14, weight: .semibold))
                }
                .foregroundStyle(PillieTheme.coral)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Capsule().fill(PillieTheme.coral.opacity(0.12)))
            }
            .opacity(shakeManager.isComplete || celebrating ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: celebrating)
            .animation(.easeOut(duration: 0.2), value: shakeManager.isComplete)
            #endif
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: PillieTheme.cardRadius).fill(PillieTheme.cardWhite))
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .overlay {
            ConfettiView(isActive: celebrating)
                .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                .allowsHitTesting(false)
        }
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feature")
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                Spacer()
                Text("Free")
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 60)
                Text("Premium")
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .frame(width: 70)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            comparisonRow(feature: "Basic Reminders", free: true, premium: true)
            comparisonRow(feature: "Historical Tracking", free: true, premium: true)
            comparisonRow(feature: "App Blocking", free: false, premium: true)
            comparisonRow(feature: "Challenge Modes", free: false, premium: true, isLast: true)
        }
        .background(RoundedRectangle(cornerRadius: PillieTheme.cardRadius).fill(PillieTheme.cardWhite))
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    private func comparisonRow(feature: String, free: Bool, premium: Bool, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textPrimary)
                Spacer()
                Image(systemName: free ? "checkmark" : "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(free ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.4))
                    .frame(width: 60)
                Image(systemName: premium ? "checkmark" : "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(premium ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.4))
                    .frame(width: 70)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast { Divider().padding(.leading, 16) }
        }
    }

    // MARK: - Cancel Caption

    private var cancelCaption: some View {
        Text("Cancel anytime \u{00B7} No commitment")
            .font(.pillie(13, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            onContinue() // TODO: StoreKit 2
        } label: {
            HStack(spacing: 8) {
                Text("Unlock Full Access")
                Image(systemName: "lock.open.fill")
            }
        }
        .buttonStyle(.pillieDark)
    }
}

#Preview {
    PremiumChallengePreviewView(onBack: {}, onContinue: {})
}
