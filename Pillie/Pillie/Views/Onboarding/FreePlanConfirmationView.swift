//
//  FreePlanConfirmationView.swift
//  Pillie
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
    let note: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle]
            + confirmations.flatMap { [$0.title, $0.detail] }
            + [note, primaryCTA]
    }

    static let `default` = FreePlanConfirmationContent(
        title: "You're all set with",
        titleAccent: "Pillie",
        subtitle: "Your free plan is active. Pillie will use the reminder setup you just configured.",
        confirmations: [
            Confirmation(
                symbolName: "bell.badge.fill",
                tint: Color(hex: "8C84A9"),
                background: PillieTheme.lavender,
                title: "Daily reminders",
                detail: "Active at your chosen reminder time"
            ),
            Confirmation(
                symbolName: "sparkles",
                tint: PillieTheme.coral,
                background: PillieTheme.coralLight,
                title: "Smart reminders",
                detail: "Personalized nudges based on your routine"
            ),
            Confirmation(
                symbolName: "calendar.badge.checkmark",
                tint: Color(hex: "7DA37B"),
                background: PillieTheme.sage,
                title: "Cycle tracking",
                detail: "Logging and timeline tracking are ready"
            )
        ],
        note: "You can adjust reminders and tracking later in Settings.",
        primaryCTA: "Start Using Pillie"
    )
}

struct FreePlanConfirmationView: View {
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        successIcon
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        confirmationRows
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        noteText
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, PillieTheme.scrollBottomPaddingWithCTA)
                }
            }

            VStack {
                Spacer()
                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .background(
                        LinearGradient(
                            colors: [PillieTheme.bg.opacity(0), PillieTheme.bg, PillieTheme.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -20)
                        .ignoresSafeArea(.all, edges: .bottom)
                    )
            }
            .ignoresSafeArea(.all, edges: .bottom)
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
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: PersonalizationOnboardingProgress.fraction(for: 10),
            badge: PersonalizationOnboardingProgress.badge(for: 10),
            onBack: onBack
        )
    }

    private var successIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color(hex: "7DA37B"))
                .frame(width: 92, height: 92)
                .background(PillieTheme.sage, in: RoundedRectangle(cornerRadius: 30))
                .shadow(color: PillieTheme.cardShadow, radius: 12, y: 5)
                .accessibilityHidden(true)

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 36, height: 36)
                .background(PillieTheme.coralLight, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                }
                .offset(x: 8, y: -8)
                .accessibilityHidden(true)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 10) {
            (Text("\(content.title) ")
                .foregroundStyle(PillieTheme.textPrimary)
             + Text(content.titleAccent)
                .foregroundStyle(PillieTheme.coral))
            .font(.pillieExtraBold(29))
            .multilineTextAlignment(.center)

            Text(content.subtitle)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 286)
        }
    }

    private var confirmationRows: some View {
        VStack(spacing: 10) {
            ForEach(Array(content.confirmations.enumerated()), id: \.offset) { _, confirmation in
                confirmationRow(confirmation)
            }
        }
    }

    private func confirmationRow(_ confirmation: FreePlanConfirmationContent.Confirmation) -> some View {
        HStack(spacing: 14) {
            Image(systemName: confirmation.symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(confirmation.tint)
                .frame(width: 46, height: 46)
                .background(confirmation.background, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(confirmation.title)
                    .font(.pillie(14, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(confirmation.detail)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color(hex: "7DA37B"))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)
    }

    private var noteText: some View {
        Text(content.note)
            .font(.pillie(11, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.68))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 12)
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
