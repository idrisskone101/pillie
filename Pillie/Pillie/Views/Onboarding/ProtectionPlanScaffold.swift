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

/// Single source of truth for the numbered plan-builder progress shown from the first
/// calibration question through Reminder Time (#77). Centralizing it keeps the bar
/// advancing coherently — the legacy approach hard-coded `index/total` per screen,
/// which left Acquisition reading "10/10" while three more setup screens still
/// followed. A later slice extends `numberedSteps` instead of re-numbering every view.
enum ProtectionPlanProgressIndex {
    /// The bespoke intro screens (Welcome, Analytics Consent, Early Value Proof, Review
    /// Prompt) precede the numbered steps and are counted in the denominator, matching
    /// the shipped scheme where Distraction Choices is step 5.
    static let introScreens = 4

    /// The ordered steps that show the numbered progress header, first question
    /// through Reminder Time.
    static let numberedSteps: [OnboardingFlow.Step] = [
        .painPoints,        // Distraction Choices
        .goal,              // Delay Consequence
        .missFrequency,     // Failure Frequency
        .riskWindow,
        // .draftBlockedApps retired (the draft-blocklist question was removed).
        .acquisitionSource,
        .method,            // Routine Basics — Method
        .schedule,          // Routine Basics — Details
        .reminderTime,      // Reminder Time
    ]

    static var total: Int { introScreens + numberedSteps.count }

    /// The progress to show for a numbered step. Unknown steps fall back to a full bar.
    static func progress(for step: OnboardingFlow.Step) -> ProtectionPlanProgress {
        let position = numberedSteps.firstIndex(of: step).map { introScreens + $0 + 1 } ?? total
        return ProtectionPlanProgress(index: position, total: total)
    }
}

struct ProtectionPlanScaffold<Content: View>: View {
    var progress: ProtectionPlanProgress? = nil
    var onBack: (() -> Void)? = nil

    let primaryTitle: String
    var primaryIcon: String? = "arrow.right"
    /// Whether the primary icon gets the gentle horizontal "go" nudge. Directional
    /// arrows nudge; a static icon (e.g. a shield on a "Save" CTA) should not.
    var animatesPrimaryIcon: Bool = true
    var isPrimaryEnabled: Bool = true
    /// Shows a spinner in place of the icon and blocks further taps while the
    /// screen waits on async work (e.g. the iOS notification permission prompt),
    /// so users get progress feedback instead of a dead button to rage-click (#196).
    var isPrimaryLoading: Bool = false
    let onPrimary: () -> Void

    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    /// Renders the primary CTA above the secondary (skip) instead of the default
    /// secondary-above-primary order. Opt-in per screen so the primary is not
    /// bottom-anchored — used where the screen wants "Continue" to lead.
    var primaryAboveSecondary: Bool = false

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
                    .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
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
        // Default: secondary (skip) above the primary, so the dark primary CTA stays
        // bottom-anchored at exactly the same position as single-CTA screens.
        // Otherwise the primary sits higher on screens that have a skip and visibly
        // slides down when transitioning to a screen without one. Screens that opt into
        // `primaryAboveSecondary` lead with the primary instead.
        VStack(spacing: 12) {
            if primaryAboveSecondary {
                primaryButton
                secondaryButton
            } else {
                secondaryButton
                primaryButton
            }
        }
    }

    @ViewBuilder private var secondaryButton: some View {
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

    private var primaryButton: some View {
        Button(action: onPrimary) {
            HStack(spacing: 10) {
                Text(primaryTitle)
                if isPrimaryLoading {
                    ProgressView()
                        .tint(.white)
                } else if let primaryIcon {
                    Image(systemName: primaryIcon)
                        .offset(x: animatesPrimaryIcon ? arrowNudge : 0)
                }
            }
        }
        .buttonStyle(.pillieDark)
        .disabled(!isPrimaryEnabled || isPrimaryLoading)
        // A loading CTA keeps full opacity: it is busy, not unavailable.
        .opacity(isPrimaryEnabled || isPrimaryLoading ? 1 : 0.38)
        .accessibilityIdentifier("protectionPlanPrimaryCTA")
    }
}
