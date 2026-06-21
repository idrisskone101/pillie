//
//  SmartRemindersMigrationNoticeSheet.swift
//  Pillie
//

import SwiftUI

/// One-time, info-first notice shown to pre-existing free users when Smart Reminders
/// moves to Pillie+ (ADR 0004 / #104). It leads with reassurance that the daily reminder
/// is still active, then reuses the Smart Reminders upsell framing (#102) with an upgrade
/// path. Eligibility and the once-only marker live in `SmartRemindersMigrationNotice`.
struct SmartRemindersMigrationNoticeSheet: View {
    let content: SmartRemindersMigrationNotice.Content

    static let presentationHeight: CGFloat = 440

    init(content: SmartRemindersMigrationNotice.Content = SmartRemindersMigrationNotice.content) {
        self.content = content
    }

    @State private var showPaywall = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dismiss) private var dismiss
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Reassurance first: the primary daily reminder stays free and unchanged.
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PillieTheme.sage)

                Text(content.reassuranceTitle)
                    .font(.pillieExtraBold(24))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(content.reassuranceBody)
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Then introduce Smart Reminders as a Plus perk (reused upsell copy).
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PillieTheme.coral)
                    Text(content.upsell.featureName)
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }

                Text(content.upsell.featureDescription)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                Button {
                    let response = plusFeedback.openPaywallOrStartPurchase(accessibilityReduceMotion: accessibilityReduceMotion)
                    telemetry.smartRemindersMigrationNoticeUpgradeTapped()
                    withAnimation(response.motionProfile.animation) {
                        showPaywall = true
                    }
                } label: {
                    Text("Upgrade to Pillie+")
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    let response = plusFeedback.dismissOrContinueFree(accessibilityReduceMotion: accessibilityReduceMotion)
                    telemetry.smartRemindersMigrationNoticeDismissed()
                    withAnimation(response.motionProfile.animation) {
                        dismiss()
                    }
                } label: {
                    Text("Got It")
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.bg)
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                onBack: { showPaywall = false },
                onContinue: {
                    showPaywall = false
                    dismiss()
                },
                onSkip: {
                    showPaywall = false
                    dismiss()
                }
            )
        }
        .onAppear {
            telemetry.smartRemindersMigrationNoticeViewed()
        }
    }
}
