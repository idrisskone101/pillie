//
//  TrialGrantedMomentView.swift
//  Pillie
//
//  Issue #164 — Trial Granted Moment (ADR 0007). Replaces the retired onboarding
//  paywall: a non-purchase announcement that the Reverse Trial has started.
//  Faithful to the Claude Design "Mapped, warmer" variant 2a: a coral
//  "14 days free · no card" badge, the "Your next two weeks, on us." headline,
//  a two-week timeline card (Today glowing coral with inline perk chips →
//  Day 12 heads-up → Day 14 choice), the one-line App Review pre-trial
//  disclosure, and a single continue action. It offers nothing to buy and has
//  no decline path. The trial grant itself is written by the flow container
//  when the screen shows — the view stays presentation-only.
//

import SwiftUI

/// Copy for the Trial Granted Moment. Entirely fixed — the screen personalizes
/// nothing. Kept as a value type so the App Review disclosure line and the
/// no-purchase-UI boundary are testable without driving the SwiftUI view.
struct TrialGrantedMomentContent {
    struct Perk {
        let title: String
        let symbolName: String
    }

    struct TimelineDay {
        let label: String
        let title: String
        let detail: String
        let symbolName: String
        let circleBackground: Color
        let symbolColor: Color
    }

    struct Today {
        let label: String
        let title: String
        let perks: [Perk]
    }

    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String
    let today: Today
    let laterDays: [TimelineDay]
    /// The App Review pre-trial disclosures as one plain line: trial duration,
    /// what turns off at expiry, and the post-trial price (ADR 0007).
    let disclosure: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle, today.label, today.title]
            + today.perks.map(\.title)
            + laterDays.flatMap { [$0.label, $0.title, $0.detail] }
            + [disclosure, primaryCTA]
    }

    static var `default`: TrialGrantedMomentContent { localized() }

    static func localized(
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy
    ) -> TrialGrantedMomentContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }
        return TrialGrantedMomentContent(
            badge: commerce("trial.granted.badge"),
            title: commerce("trial.granted.headline"),
            titleAccent: commerce("trial.granted.headline_accent"),
            subtitle: commerce("trial.granted.subtitle"),
            today: Today(
                label: commerce("trial.timeline.today"),
                title: commerce("trial.timeline.today_title"),
                perks: [
                    Perk(title: commerce("paywall.feature.app_blocking"), symbolName: "nosign"),
                    Perk(
                        title: commerce("paywall.feature.shake"),
                        symbolName: "iphone.radiowaves.left.and.right"
                    ),
                    Perk(
                        title: commerce("paywall.feature.smart_reminders"),
                        symbolName: "bell.fill"
                    ),
                    Perk(
                        title: commerce("paywall.feature.custom_messages"),
                        symbolName: "text.bubble.fill"
                    ),
                ]
            ),
            laterDays: [
                TimelineDay(
                    label: commerce("trial.granted.warning.label"),
                    title: commerce("trial.granted.warning.title"),
                    detail: commerce("trial.granted.warning.detail"),
                    symbolName: "bell.fill",
                    circleBackground: PillieTheme.lavender,
                    symbolColor: PillieTheme.textPrimary
                ),
                TimelineDay(
                    label: commerce("trial.granted.choice.label"),
                    title: commerce("trial.granted.choice.title"),
                    detail: commerce(
                        trialEndTerms == .hardPaywall
                            ? "trial.granted.choice.detail.hard_paywall"
                            : "trial.granted.choice.detail"
                    ),
                    symbolName: "leaf.fill",
                    circleBackground: PillieTheme.sage,
                    symbolColor: PillieTheme.verifiedGreen
                ),
            ],
            disclosure: commerce(
                trialEndTerms == .hardPaywall
                    ? "trial.granted.disclosure.hard_paywall"
                    : "trial.granted.disclosure"
            ),
            primaryCTA: commerce("trial.granted.cta")
        )
    }
}

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

// MARK: - Headline (badge + title + subtitle)

private struct TrialGrantedHeadline: View {
    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text(badge.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(PillieTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PillieTheme.coral, in: Capsule())

            (Text("\(title)\n")
                .foregroundStyle(PillieTheme.textPrimary)
             + Text(titleAccent)
                .foregroundStyle(PillieTheme.coral))
            .font(.pillie(32, weight: .black))
            .tracking(-0.5)
            .lineSpacing(1)
            .lineLimit(2)
            .minimumScaleFactor(0.85)

            Text(subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Timeline card (Today glow → Day 12 → Day 14)

private struct TrialGrantedTimelineCard: View {
    let today: TrialGrantedMomentContent.Today
    let laterDays: [TrialGrantedMomentContent.TimelineDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrialGrantedTodayHighlight(today: today)

            ForEach(Array(laterDays.enumerated()), id: \.offset) { index, day in
                TrialGrantedTimelineRow(day: day, showsConnector: index < laterDays.count - 1)
                    .padding(.horizontal, 14)
                    .padding(.top, index == 0 ? 14 : 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        }
        .shadow(
            color: PillieTheme.cardShadow,
            radius: PillieTheme.cardShadowRadius,
            y: PillieTheme.cardShadowY
        )
    }
}

private struct TrialGrantedTodayHighlight: View {
    let today: TrialGrantedMomentContent.Today

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 34, height: 34)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            .background(
                // The design's soft coral glow ring around today's marker.
                Circle()
                    .fill(PillieTheme.coral.opacity(0.25))
                    .frame(width: 44, height: 44)
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(today.label.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(PillieTheme.patchChangeRose)

                Text(today.title)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                TrialGrantedPerkChips(perks: today.perks)
                    .padding(.top, 5)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PillieTheme.coralLight)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(PillieTheme.coral.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct TrialGrantedPerkChips: View {
    let perks: [TrialGrantedMomentContent.Perk]

    var body: some View {
        // A wrapping flow so each chip keeps its label on one line (e.g. "Smart
        // Reminders" never breaks) and wraps to the next row only when the full
        // chip would overflow the card.
        ProtectionPlanFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(perks, id: \.title) { perk in
                chip(perk)
            }
        }
    }

    private func chip(_ perk: TrialGrantedMomentContent.Perk) -> some View {
        HStack(spacing: 5) {
            Image(systemName: perk.symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(perk.title)
                .font(.pillie(12, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(PillieTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(PillieTheme.cardWhite, in: Capsule())
    }
}

private struct TrialGrantedTimelineRow: View {
    let day: TrialGrantedMomentContent.TimelineDay
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(day.circleBackground)
                        .frame(width: 34, height: 34)
                    Image(systemName: day.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(day.symbolColor)
                }
                .accessibilityHidden(true)

                if showsConnector {
                    Rectangle()
                        .fill(PillieTheme.sage.opacity(0.9))
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(day.label.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(PillieTheme.textMuted)

                Text(day.title)
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(day.detail)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsConnector ? 14 : 0)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    TrialGrantedMomentView(onBack: {}, onContinue: {})
}
