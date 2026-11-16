//
//  BlockingSetupLockedView.swift
//  Pillie
//
//  The blocking step for someone who cannot set blocking up: no Plus access,
//  or she chose the free plan. It shows no rehearsal.
//

import SwiftUI

struct BlockingSetupLockedView: View {
    @Environment(\.locale) private var locale
    @State private var animateIn = false

    let trialEndTerms: TrialEndAccessTerms
    let onBack: () -> Void
    let onContinue: () -> Void

    private var content: BlockingSetupLockedContent {
        BlockingSetupLockedContent.localized(locale: locale, trialEndTerms: trialEndTerms)
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ProtectionPlanProgressHeader(
                    progress: ProtectionPlanProgressIndex.progress(for: .appBlocking),
                    onBack: onBack
                )
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)

                heroSection
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 22)

                ScrollView(showsIndicators: false) {
                    lockedSection
                        .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                }

                Button(action: onContinue) {
                    Text(content.cta)
                }
                .buttonStyle(.pillieDark)
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
            }
        }
        .onAppear { animateIn = true }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.title)
                .font(.pillie(34, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .tracking(-0.85)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.subtitle)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.cardTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text(content.detail)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .modifier(BlockingSetupCardSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityIdentifier("blockingSetupLockedCard")
    }
}

#Preview {
    BlockingSetupLockedView(trialEndTerms: .hardPaywall, onBack: {}, onContinue: {})
}
