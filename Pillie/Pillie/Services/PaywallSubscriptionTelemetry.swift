//
//  PaywallSubscriptionTelemetry.swift
//  Pillie
//

import Foundation

struct PaywallSubscriptionTelemetry {
    static let live = PaywallSubscriptionTelemetry()

    private let analytics: AnalyticsTracking

    init(analytics: AnalyticsTracking = AnalyticsManager.shared) {
        self.analytics = analytics
    }

    func paywallViewed(source: AnalyticsSource, isFromOnboarding: Bool, isPlus: Bool) {
        track(.paywallViewed, source: source, step: isFromOnboarding ? .paywall : nil, isPlus: isPlus)
    }

    func planSelected(source: AnalyticsSource, plan: AnalyticsPlan, isPlus: Bool) {
        track(.paywallPlanSelected, source: source, plan: plan, isPlus: isPlus)
    }

    func purchaseStarted(source: AnalyticsSource, plan: AnalyticsPlan, isPlus: Bool) {
        track(.purchaseStarted, source: source, plan: plan, isPlus: isPlus)
    }

    func purchaseCompleted(source: AnalyticsSource, plan: AnalyticsPlan, isPlus: Bool) {
        track(.purchaseCompleted, source: source, plan: plan, result: .completed, isPlus: isPlus)
    }

    func purchaseFailed(source: AnalyticsSource, plan: AnalyticsPlan, isPlus: Bool) {
        track(.purchaseFailed, source: source, plan: plan, result: .failed, isPlus: isPlus)
    }

    func purchaseCancelled(source: AnalyticsSource, plan: AnalyticsPlan, isPlus: Bool) {
        track(.purchaseCancelled, source: source, plan: plan, result: .cancelled, isPlus: isPlus)
    }

    func restoreStarted(source: AnalyticsSource, isPlus: Bool) {
        track(.restoreStarted, source: source, isPlus: isPlus)
    }

    func restoreCompleted(source: AnalyticsSource, isPlus: Bool) {
        track(.restoreCompleted, source: source, result: .completed, isPlus: isPlus)
    }

    func restoreFailed(source: AnalyticsSource, isPlus: Bool) {
        track(.restoreFailed, source: source, result: .failed, isPlus: isPlus)
    }

    func continueFreeSelected(source: AnalyticsSource, isFromOnboarding: Bool, isPlus: Bool) {
        track(.continueFreeSelected, source: source, step: isFromOnboarding ? .paywall : nil, isPlus: isPlus)
    }

    func plusUpsellViewed(isPlus: Bool) {
        track(.plusUpsellViewed, source: .upsell, isPlus: isPlus)
    }

    func plusUpsellDismissed(isPlus: Bool) {
        track(.plusUpsellDismissed, source: .upsell, isPlus: isPlus)
    }

    func plusUpsellUpgradeTapped(isPlus: Bool) {
        track(.plusUpsellUpgradeTapped, source: .upsell, isPlus: isPlus)
    }

    private func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource,
        step: AnalyticsStep? = nil,
        plan: AnalyticsPlan? = nil,
        result: AnalyticsResult? = nil,
        isPlus: Bool
    ) {
        analytics.track(
            event,
            source: source,
            step: step,
            screen: nil,
            plan: plan,
            result: result,
            setting: nil,
            acquisitionSource: nil,
            isPlus: isPlus,
            hasBlockingSelection: nil
        )
    }
}
