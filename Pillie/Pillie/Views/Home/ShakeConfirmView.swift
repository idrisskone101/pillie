//
//  ShakeConfirmView.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ShakeConfirmView: View {
    let action: DoseScheduleAction
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @State private var shakeManager = ShakeDetectionManager()
    @State private var appeared = false
    @State private var celebrating = false
    @State private var emojiOffset: CGFloat = 0
    #if os(iOS)
    @State private var completionFeedback = UINotificationFeedbackGenerator()
    #endif

    private var emoji: String { action.method.emoji }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            ConfettiView(isActive: celebrating)

            VStack(spacing: 32) {
                Spacer()

                // Headline
                Text(celebrating ? "Done!" : "Shake to Confirm")
                    .font(.pillieHeadline())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Subtitle
                Text(celebrating ? action.ctaLabel : "Give your phone a shake\nto mark today's dose")
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.05))

                // Progress ring + emoji
                ZStack {
                    Circle()
                        .stroke(PillieTheme.sage, lineWidth: 6)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: shakeManager.progress)
                        .stroke(
                            PillieTheme.coral,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.3), value: shakeManager.progress)

                    Text(emoji)
                        .font(.system(size: 56))
                        .offset(y: emojiOffset)
                        .scaleEffect(celebrating ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: celebrating)
                }
                .scaleEffect(emojiOffset != 0 ? 1.02 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: emojiOffset)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // Shake counter
                Text("\(shakeManager.shakeCount) / \(shakeManager.requiredShakes)")
                    .font(.pillie(20, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: shakeManager.shakeCount)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                Spacer()

                // Simulator tap-to-shake fallback
                #if targetEnvironment(simulator)
                if !shakeManager.isComplete && !celebrating {
                    Button {
                        shakeManager.simulateShake()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Tap to Simulate Shake")
                        }
                    }
                    .buttonStyle(.pillieDark)
                    .padding(.horizontal, 24)
                }
                #endif

                if !celebrating {
                    // Tap-to-confirm alternative (accessibility — WCAG 2.5.4)
                    Button {
                        completeShake()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Tap to Confirm Instead")
                        }
                        .font(.pillie(18, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: PillieTheme.ctaHeight)
                        .background(PillieTheme.sage)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                    // Cancel
                    Button {
                        shakeManager.stopDetecting()
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.pillie(16, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        }
        .onAppear {
            #if os(iOS)
            completionFeedback.prepare()
            #endif
            shakeManager.startDetecting()
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
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
                completeShake()
            }
        }
    }

    // MARK: - Private

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
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    private func completeShake() {
        guard !celebrating else { return }
        shakeManager.stopDetecting()

        // Fill progress if skipped via tap alternative
        if !shakeManager.isComplete {
            shakeManager.fillToComplete()
        }

        #if os(iOS)
        completionFeedback.notificationOccurred(.success)
        #endif

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            celebrating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onConfirm()
        }
    }
}
