//
//  StatsRow.swift
//  Pillie
//

import SwiftUI

struct StatsRow: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) var store
    @State private var showPaywall = false
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    private var isPlus: Bool { SubscriptionManager.shared.hasPlusAccess }

    private var blockingStatusText: String {
        let mgr = AppBlockingManager.shared
        if !mgr.blockingEnabled || !mgr.hasAppsSelected {
            return PillieLocalization.string("global.status.off", locale: locale)
        }
        return PillieLocalization.string("global.status.on", locale: locale)
    }

    private var blockingSubtitle: String {
        PillieLocalization.string("today.protection.status_title", locale: locale)
    }

    var body: some View {
        let _ = store.protocolChangeVersion
        let currentStreak = store.currentStreak
        HStack(spacing: 12) {
            // Streak card
            VStack(spacing: 6) {
                statIcon("flame.fill", tint: PillieTheme.coral)

                Text("\(currentStreak)")
                    .font(.pillie(24, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(valueChangeAnimation, value: currentStreak)

                Text(PillieLocalization.string("today.streak.title", locale: locale))
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.coral)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(PillieTheme.coralLight)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(PillieTheme.coralFaded, lineWidth: 1)
            )

            // Blocking card
            if isPlus {
                blockingCardContent
                    .modifier(StatsCardStyle())
            } else {
                Button {
                    let response = plusFeedback.openPaywallOrStartPurchase(accessibilityReduceMotion: accessibilityReduceMotion)
                    withAnimation(response.motionProfile.animation) {
                        showPaywall = true
                    }
                } label: {
                    lockedBlockingCardContent
                        .modifier(StatsCardStyle())
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                paywallSurface: .homeBlockingCard,
                onBack: { showPaywall = false },
                onContinue: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
        }
    }

    private var blockingCardContent: some View {
        VStack(spacing: 6) {
            statIcon("lock.shield.fill", tint: PillieTheme.sage)

            Text(blockingStatusText)
                .font(.pillie(24, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                .contentTransition(.opacity)
                .animation(valueChangeAnimation, value: blockingStatusText)

            Text(blockingSubtitle)
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                .contentTransition(.opacity)
                .animation(valueChangeAnimation, value: blockingSubtitle)
        }
    }

    private var lockedBlockingCardContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundStyle(PillieTheme.textMuted)

            Text("Pillie+")
                .font(.pillie(24, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)

            Text(PillieLocalization.string("today.protection.status_title", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
        }
    }

    private func statIcon(_ symbolName: String, tint: Color) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .contentTransition(.opacity)
    }
}

private struct StatsCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
    }
}

#Preview {
    StatsRow()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
