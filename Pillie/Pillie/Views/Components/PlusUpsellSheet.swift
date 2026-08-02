//
//  PlusUpsellSheet.swift
//  Pillie

import SwiftUI

/// Copy for a `PlusUpsellSheet` variant, kept as a value type so the framing of
/// each Plus-gated feature can be unit-tested without rendering the view.
struct PlusUpsellContent: Equatable {
    let featureName: String
    let featureDescription: String
    let localizedFeatureKey: String
    let paywallSurface: AnalyticsPaywallSurface

    static let appBlocking = PlusUpsellContent(
        featureName: "App Blocking",
        featureDescription: "Block distracting apps until your pill is logged.",
        localizedFeatureKey: "paywall.feature.app_blocking.compact",
        paywallSurface: .plusUpsell
    )

    /// Smart Reminders reads as the follow-up escalation after the first reminder
    /// (ADR 0004), never the base daily reminder, and avoids medical/efficacy claims.
    static let smartReminders = PlusUpsellContent(
        featureName: "Smart Reminders",
        featureDescription: "Pillie sends gentle follow-up nudges until you log it.",
        localizedFeatureKey: "paywall.feature.smart_reminders",
        paywallSurface: .plusUpsell
    )

    /// Custom Reminder Messages frames the perk as writing your own private nudge.
    /// It is the user's own words (ADR 0004), so the copy stays personal and avoids
    /// medical/efficacy claims.
    static let customReminders = PlusUpsellContent(
        featureName: "Custom Messages",
        featureDescription: "Word the daily reminder yourself — what you type is what you'll see.",
        localizedFeatureKey: "paywall.feature.custom_messages.compact",
        paywallSurface: .plusUpsell
    )
}

struct PlusUpsellSheet: View {
    let featureName: String
    let featureDescription: String
    let localizedFeatureKey: String
    let paywallSurface: AnalyticsPaywallSurface

    static let compactPresentationHeight: CGFloat = 420

    init(
        featureName: String,
        featureDescription: String,
        localizedFeatureKey: String = "paywall.feature.custom_messages.compact",
        paywallSurface: AnalyticsPaywallSurface = .plusUpsell
    ) {
        self.featureName = featureName
        self.featureDescription = featureDescription
        self.localizedFeatureKey = localizedFeatureKey
        self.paywallSurface = paywallSurface
    }

    init(content: PlusUpsellContent) {
        self.featureName = content.featureName
        self.featureDescription = content.featureDescription
        self.localizedFeatureKey = content.localizedFeatureKey
        self.paywallSurface = content.paywallSurface
    }

    static func appBlocking() -> PlusUpsellSheet {
        PlusUpsellSheet(content: .appBlocking)
    }

    static func smartReminders() -> PlusUpsellSheet {
        PlusUpsellSheet(content: .smartReminders)
    }

    static func customReminders() -> PlusUpsellSheet {
        PlusUpsellSheet(content: .customReminders)
    }
    @State private var showPaywall = false
    @State private var hasTrackedView = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var restoreError: String?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PillieTheme.coral)

                Text(localizedFeatureName)
                    .font(.pillieExtraBold(24))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)

                Text(PillieLocalization.string(
                    "paywall.subtitle",
                    table: "Commerce",
                    locale: locale
                ))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                Button {
                    let response = plusFeedback.openPaywallOrStartPurchase(accessibilityReduceMotion: accessibilityReduceMotion)
                    telemetry.plusUpsellUpgradeTapped()
                    withAnimation(response.motionProfile.animation) {
                        showPaywall = true
                    }
                } label: {
                    Text(PillieLocalization.string(
                        "paywall.action.upgrade",
                        table: "Commerce",
                        locale: locale
                    ))
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    let response = plusFeedback.dismissOrContinueFree(accessibilityReduceMotion: accessibilityReduceMotion)
                    telemetry.plusUpsellDismissed()
                    withAnimation(response.motionProfile.animation) {
                        dismiss()
                    }
                } label: {
                    Text(PillieLocalization.string("global.action.not_now", locale: locale))
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }

                Button {
                    let response = plusFeedback.startRestore(accessibilityReduceMotion: accessibilityReduceMotion)
                    withAnimation(response.motionProfile.animation) {
                        isRestoring = true
                    }
                    telemetry.upsellRestoreStarted()
                    Task {
                        do {
                            try await SubscriptionManager.shared.restore()
                            if SubscriptionManager.shared.hasEntitlement {
                                telemetry.upsellRestoreCompleted()
                                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                                dismiss()
                            } else {
                                telemetry.upsellRestoreFailed()
                                let calmResponse = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                                withAnimation(calmResponse.motionProfile.animation) {
                                    showNoSubscriptionAlert = true
                                }
                            }
                        } catch {
                            telemetry.upsellRestoreFailed()
                            telemetry.trackError(.restore, error: error)
                            let calmResponse = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                            withAnimation(calmResponse.motionProfile.animation) {
                                restoreError = CommercePresentation.restoreErrorMessage(
                                    error,
                                    locale: locale
                                )
                            }
                        }
                        withAnimation(response.motionProfile.animation) {
                            isRestoring = false
                        }
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .tint(PillieTheme.textMuted)
                            .frame(height: 16)
                    } else {
                        Text(PillieLocalization.string(
                            "paywall.action.restore",
                            table: "Commerce",
                            locale: locale
                        ))
                            .font(.pillie(12, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted.opacity(0.6))
                    }
                }
                .disabled(isRestoring)
            }

        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.bg)
        .alert(PillieLocalization.string(
            "paywall.no_subscription.title",
            table: "Commerce",
            locale: locale
        ), isPresented: $showNoSubscriptionAlert) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) { }
        } message: {
            Text(PillieLocalization.string(
                "paywall.no_subscription.body",
                table: "Commerce",
                locale: locale
            ))
        }
        .alert(PillieLocalization.string(
            "paywall.restore_error.title",
            table: "Commerce",
            locale: locale
        ), isPresented: .init(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) {
                restoreError = nil
            }
        } message: {
            Text(restoreError ?? "")
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                paywallSurface: paywallSurface,
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
            guard !hasTrackedView else { return }
            hasTrackedView = true
            telemetry.plusUpsellViewed()
        }
    }

    private var localizedFeatureName: String {
        PillieLocalization.string(localizedFeatureKey, table: "Commerce", locale: locale)
    }
}
