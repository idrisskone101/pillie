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
    let handNote: String
    /// The App Review pre-trial disclosures as one plain line: trial duration,
    /// what turns off at expiry, and the post-trial price (ADR 0007).
    let disclosure: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle, today.label, today.title]
            + today.perks.map(\.title)
            + laterDays.flatMap { [$0.label, $0.title, $0.detail] }
            + [handNote, disclosure, primaryCTA]
    }

    static let `default` = TrialGrantedMomentContent(
        badge: "14 days free · no card",
        title: "Your next two weeks,",
        titleAccent: "on us.",
        subtitle: "A full trial of Pillie Plus starts now — here's how it goes.",
        today: Today(
            label: "Today",
            title: "Everything unlocks",
            perks: [
                Perk(title: "App blocking", symbolName: "nosign"),
                Perk(title: "Shake to confirm", symbolName: "iphone.radiowaves.left.and.right"),
                Perk(title: "Smart Reminders", symbolName: "bell.fill"),
                Perk(title: "Custom messages", symbolName: "text.bubble.fill"),
            ]
        ),
        laterDays: [
            TimelineDay(
                label: "Day 12",
                title: "A gentle heads-up",
                detail: "We'll remind you before your trial ends. No surprises.",
                symbolName: "bell.fill",
                circleBackground: PillieTheme.lavender,
                symbolColor: PillieTheme.textPrimary
            ),
            TimelineDay(
                label: "Day 14",
                title: "You choose",
                detail: "Keep reminders free, or stay with Plus at $29.99/year.",
                symbolName: "leaf.fill",
                circleBackground: PillieTheme.sage,
                symbolColor: PillieTheme.verifiedGreen
            ),
        ],
        handNote: "today's the fun part!",
        disclosure: "Your free trial lasts 14 days — app blocking turns off when it ends. After that, Plus is $29.99/year, or keep using reminders free.",
        primaryCTA: "Start my free trial"
    )
}

struct TrialGrantedMomentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current
    private let content = TrialGrantedMomentContent.default

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

                        handNote
                            .frame(maxWidth: .infinity)
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
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
        // The plan-builder questions are behind us; the bar reads full, matching
        // the design's fully-coral progress track.
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: 1,
            badge: "Trial granted",
            onBack: onBack
        )
    }

    private var handNote: some View {
        Text(content.handNote)
            .font(.pillieHandwriting(size: 27))
            .foregroundStyle(PillieTheme.textMuted)
            .rotationEffect(.degrees(-2))
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
        // Two leading-aligned rows of two chips, matching the design's inline wrap.
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(stride(from: 0, to: perks.count, by: 2)), id: \.self) { rowStart in
                HStack(spacing: 6) {
                    ForEach(rowStart..<min(rowStart + 2, perks.count), id: \.self) { index in
                        chip(perks[index])
                    }
                }
            }
        }
    }

    private func chip(_ perk: TrialGrantedMomentContent.Perk) -> some View {
        HStack(spacing: 5) {
            Image(systemName: perk.symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(perk.title)
                .font(.pillie(12, weight: .semibold))
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
