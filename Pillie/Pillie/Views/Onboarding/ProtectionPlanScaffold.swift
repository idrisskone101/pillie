//
//  ProtectionPlanScaffold.swift
//  Pillie
//
//  Shared chrome for Protection Plan Onboarding screens: a soft branded
//  background, an optional progress header (back button + section progress),
//  scrollable content, and a fixed bottom CTA stack with
//  explicit enabled/disabled states. Later calibration screens reuse this so the
//  flow container stays consistent.
//

import SwiftUI

/// Visible section progress for onboarding. `nil` on screens that intentionally
/// hide progress (e.g. Welcome).
struct ProtectionPlanProgress: Equatable {
    enum Section: Int, CaseIterable {
        case seeHowPillieWorks = 1
        case personalizeYourPlan
        case setYourReminder

        var title: String {
            switch self {
            case .seeHowPillieWorks:
                PillieLocalization.string("accessibility.progress.intro.title")
            case .personalizeYourPlan:
                PillieLocalization.string("accessibility.progress.personalize.title")
            case .setYourReminder:
                PillieLocalization.string("accessibility.progress.reminder.title")
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .seeHowPillieWorks:
                PillieLocalization.string("accessibility.progress.intro")
            case .personalizeYourPlan:
                PillieLocalization.string("accessibility.progress.personalize")
            case .setYourReminder:
                PillieLocalization.string("accessibility.progress.reminder")
            }
        }
    }

    let section: Section

    var index: Int { section.rawValue }
    var total: Int { Section.allCases.count }
    var title: String { section.title }

    var fraction: CGFloat {
        return CGFloat(index) / CGFloat(total)
    }

    var accessibilityLabel: String { section.accessibilityLabel }
}

/// Single source of truth for the stable, user-facing onboarding sections. Individual
/// screens can be inserted, retired, or skipped without changing the three-section
/// expectation or making progress move backward.
enum ProtectionPlanProgressIndex {
    static func progress(for step: OnboardingFlow.Step) -> ProtectionPlanProgress {
        let section: ProtectionPlanProgress.Section = switch step {
        case .welcome, .analyticsConsent, .productDemo, .plusBlockingDemo:
            .seeHowPillieWorks
        case .reviewPrompt, .painPoints, .goal, .missFrequency, .acquisitionSource,
             .riskWindow, .draftBlockedApps:
            .personalizeYourPlan
        case .method, .schedule, .reminderTime, .reminderPlan, .paywall,
             .freePlanConfirmation, .appBlocking, .complete, .mechanismProof,
             .protectionPlanReady, .trialGranted:
            .setYourReminder
        }
        return ProtectionPlanProgress(section: section)
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
    /// Some interactive screens teach a gesture without presenting the teaching
    /// copy as a tappable CTA. Those screens can temporarily omit the primary.
    var showsPrimary: Bool = true
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
                if showsPrimary { primaryButton }
                secondaryButton
            } else {
                secondaryButton
                if showsPrimary { primaryButton }
            }
        }
    }

    @ViewBuilder private var secondaryButton: some View {
        if let secondaryTitle, let onSecondary {
            Button(action: onSecondary) {
                Text(secondaryTitle)
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.7)
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
