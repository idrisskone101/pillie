//
//  TrialGrantedMomentView.swift
//  Pillie
//
//  Issue #164 — Trial Granted Moment (ADR 0007). Replaces the retired onboarding
//  paywall: a non-purchase announcement that the Reverse Trial has started.
//  Faithful to the Claude Design "Mapped, warmer" variant 2a: a coral
//  "14 active days free · no card" badge, the "Your next two weeks, on us." headline,
//  a two-week timeline card (Today glowing coral with inline perk chips →
//  Day 12 heads-up → Day 14 choice), the one-line App Review pre-trial
//  disclosure, and a single continue action. It offers nothing to buy and has
//  no decline path. The trial grant itself is written by the flow container
//  when the screen shows — the view stays presentation-only.
//

import SwiftUI

struct TrialGrantedMomentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current
    private let subscriptionManager = SubscriptionManager.shared
    private var trialEndTerms: TrialEndAccessTerms {
        let termsCohort = subscriptionManager.trialTermsCohort
            ?? TrialInstallCohort.storedAssignment()
            ?? HardPaywallPolicy.cohort(forTrialGrantedAt: Date())
        return HardPaywallPolicy.terms(
            for: termsCohort,
            hardPaywallEnabled: subscriptionManager.hardPaywallEnabled
        )
    }
    private var content: TrialGrantedMomentContent {
        TrialGrantedMomentContent.localized(
            locale: locale,
            trialEndTerms: trialEndTerms
        )
    }

    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        TrialGrantedHeadline(
                            badge: content.badge,
                            title: content.title,
                            titleAccent: content.titleAccent,
                            subtitle: content.subtitle
                        )
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        TrialGrantedTimelineCard(today: content.today, laterDays: content.laterDays)
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger5))
                    .padding(.horizontal, 24)
                    .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
            }
        }
        .onAppear {
            animateIn = true
            guard PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: reduceMotion,
                performanceTier: performanceTier
            ) else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
    }

    private var header: some View {
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: ProtectionPlanProgressIndex.progress(for: .trialGranted),
            onBack: onBack
        )
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text(content.disclosure)
                .font(.pillie(12, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("trialGrantedDisclosure")

            Button(action: onContinue) {
                HStack(spacing: 10) {
                    Text(content.primaryCTA)
                    Image(systemName: "checkmark")
                }
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("trialGrantedPrimaryCTA")
        }
    }
}
