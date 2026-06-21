//
//  FreePlanConfirmationView.swift
//  Pillie
//
//  Reminder-Only Onboarding Completion ("You're all set with Pillie"). Hero design:
//  Option 3 — Verified seal (rosette) from the Free Plan Confirmation design draft.
//

import SwiftUI

struct FreePlanConfirmationContent {
    struct Confirmation {
        let symbolName: String
        let tint: Color
        let background: Color
        let title: String
        let detail: String
    }

    let title: String
    let titleAccent: String
    let subtitle: String
    let confirmations: [Confirmation]
    let handNote: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle]
            + confirmations.flatMap { [$0.title, $0.detail] }
            + [handNote, primaryCTA]
    }

    static let `default` = FreePlanConfirmationContent(
        title: "You're all set with",
        titleAccent: "Pillie",
        subtitle: "Your free plan is active. Pillie will use the reminder setup you just configured.",
        confirmations: [
            Confirmation(
                symbolName: "bell.fill",
                tint: PillieTheme.textPrimary,
                background: PillieTheme.lavender,
                title: "Daily reminders",
                detail: "Active at your chosen reminder time"
            ),
            Confirmation(
                symbolName: "calendar.badge.checkmark",
                tint: PillieTheme.textPrimary,
                background: PillieTheme.sage,
                title: "Cycle tracking",
                detail: "Logging and timeline tracking are ready"
            )
        ],
        handNote: "you're all set, bestie!",
        primaryCTA: "Start Using Pillie"
    )
}

struct FreePlanConfirmationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current
    private let content = FreePlanConfirmationContent.default

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

                Spacer(minLength: 12)

                VStack(spacing: 22) {
                    verifiedSealHero
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                    titleSection
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                    confirmationRows
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                    handNote
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 16)

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
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
        let progress = ProtectionPlanProgressIndex.progress(for: .freePlanConfirmation)
        return PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: progress.fraction,
            badge: progress.badge,
            onBack: onBack
        )
    }

    // MARK: - Hero (Option 3 — verified seal)

    private var verifiedSealHero: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 58, weight: .regular))
            .foregroundStyle(PillieTheme.verifiedGreen)
            .frame(width: 104, height: 104)
            .background(PillieTheme.sage, in: RoundedRectangle(cornerRadius: 30))
            .shadow(color: PillieTheme.verifiedGreen.opacity(0.3), radius: 15, y: 16)
            .padding(.top, 18)
            .accessibilityHidden(true)
    }

    private var titleSection: some View {
        VStack(spacing: 12) {
            (Text("\(content.title) ")
                .foregroundStyle(PillieTheme.textPrimary)
             + Text(content.titleAccent)
                .foregroundStyle(PillieTheme.coral))
            .font(.pillieTitle())
            .tracking(-0.5)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.7)

            Text(content.subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }

    private var confirmationRows: some View {
        VStack(spacing: 14) {
            ForEach(Array(content.confirmations.enumerated()), id: \.offset) { _, confirmation in
                confirmationRow(confirmation)
            }
        }
    }

    private func confirmationRow(_ confirmation: FreePlanConfirmationContent.Confirmation) -> some View {
        HStack(spacing: 16) {
            Image(systemName: confirmation.symbolName)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(confirmation.tint)
                .frame(width: 52, height: 52)
                .background(confirmation.background, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(confirmation.title)
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(confirmation.detail)
                    .font(.pillie(14, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(PillieTheme.sage)
                    .frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(PillieTheme.verifiedGreen)
            }
            .accessibilityHidden(true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        }
        .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)
    }

    private var handNote: some View {
        Text(content.handNote)
            .font(.pillieHandwriting(size: 27))
            .foregroundStyle(PillieTheme.textMuted)
            .rotationEffect(.degrees(-3))
            .padding(.top, 2)
    }

    private var footer: some View {
        Button {
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Text(content.primaryCTA)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("freePlanConfirmationStartButton")
    }
}

#Preview {
    FreePlanConfirmationView(onBack: {}, onContinue: {})
}
