//
//  ProtectionPlanScaffold.swift
//  Pillie
//
//  Shared chrome for Protection Plan Onboarding screens: a soft branded
//  background, an optional progress header (back button + segmented progress +
//  "STEP n/N" badge), scrollable content, and a fixed bottom CTA stack with
//  explicit enabled/disabled states. Later calibration screens reuse this so the
//  flow container stays consistent.
//

import SwiftUI

/// Visible progress for a calibration step. `nil` on screens that intentionally
/// hide progress (e.g. Welcome).
struct ProtectionPlanProgress: Equatable {
    let index: Int
    let total: Int

    var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(index) / CGFloat(total)
    }

    var badge: String { "STEP \(index)/\(total)" }
}

struct ProtectionPlanScaffold<Content: View>: View {
    var progress: ProtectionPlanProgress? = nil
    var onBack: (() -> Void)? = nil

    let primaryTitle: String
    var primaryIcon: String? = "arrow.right"
    var isPrimaryEnabled: Bool = true
    let onPrimary: () -> Void

    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var blobPhase: CGFloat = 0
    @State private var arrowNudge: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                if let progress {
                    ProtectionPlanProgressHeader(
                        progress: progress,
                        onBack: { onBack?() }
                    )
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                        .padding(.top, progress == nil ? 8 : 4)
                        .padding(.bottom, 24)
                }
                // Only scroll/bounce when content actually overflows. When it fits
                // (the Early Value Proof case), there's no vertical gesture to
                // conflict with the horizontal drag on the demo.
                .scrollBounceBehavior(.basedOnSize)

                ctaStack
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            withAnimation(PillieTheme.fadeInUpCurve) { appeared = true }

            guard animationsEnabled else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
            // A gentle, ongoing "go" nudge for the CTA arrow.
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.6)) {
                arrowNudge = 4
            }
        }
    }

    private var ctaStack: some View {
        // Primary on top, secondary below. The stack is bottom-anchored, so the
        // bottom of the CTA area is consistent across screens.
        VStack(spacing: 12) {
            Button(action: onPrimary) {
                HStack(spacing: 10) {
                    Text(primaryTitle)
                    if let primaryIcon {
                        Image(systemName: primaryIcon)
                            .offset(x: arrowNudge)
                    }
                }
            }
            .buttonStyle(.pillieDark)
            .disabled(!isPrimaryEnabled)
            .opacity(isPrimaryEnabled ? 1 : 0.38)
            .accessibilityIdentifier("protectionPlanPrimaryCTA")

            if let secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(PillieTheme.textMuted.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: PillieTheme.cardShadow, radius: 12, y: 6)
                .accessibilityIdentifier("protectionPlanSecondaryCTA")
            }
        }
    }
}
