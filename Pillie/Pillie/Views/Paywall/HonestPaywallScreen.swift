//
//  HonestPaywallScreen.swift
//  Pillie
//

import SwiftUI
import RevenueCat

struct HonestPaywallScreen: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    let board: HonestPaywallBoard
    let surface: AnalyticsPaywallSurface
    let onDismiss: () -> Void
    var onResolved: (() -> Void)? = nil
    var trialStats: TrialEndOwnStats? = nil
    var declineFeedbackContent: TrialDeclineFeedbackContent? = nil
    var routeContinueFree: (() -> TrialDeclineFeedbackRoute)? = nil

    @State private var selection: PaywallPurchaseIntent = .subscribe(.year)
    @State private var offerings: Offerings?
    @State private var activeAlert: PaywallAlert?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseSucceeded = false
    @State private var successOutcome: TrialEndSuccessOutcome = .purchased(.annual)
    @State private var showDeclineFeedback = false

    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    private var scene: HonestPaywallScene {
        HonestPaywallSceneBuilder.build(
            board: board,
            offerings: offeringsSnapshot,
            selection: selection,
            locale: locale
        )
    }

    private var offeringsSnapshot: PaywallOfferingsSnapshot? {
        let snapshot = offerings.flatMap(PaywallOfferingsSnapshot.parse)
        #if DEBUG
        if let display = UserDefaults.standard.string(forKey: Self.debugLifetimeDisplayKey) {
            return snapshot?.withLifetimeDisplay(display)
        }
        #endif
        return snapshot
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()
            screenContent
        }
        .interactiveDismissDisabled(!board.chrome.allowsInteractiveDismiss)
        .animation(PillieTheme.fadeInUpCurve, value: purchaseSucceeded)
        .animation(PillieTheme.fadeInUpCurve, value: showDeclineFeedback)
        .onAppear {
            trackViewed()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.debugSuccessStateKey) {
                UserDefaults.standard.removeObject(forKey: Self.debugSuccessStateKey)
                purchaseSucceeded = true
            }
            #endif
        }
        .task {
            subscriptionManager.configure()
            async let offeringsLoaded: Void = loadOfferings()
            await subscriptionManager.refreshStatus()
            await offeringsLoaded
        }
        .paywallAlert($activeAlert, surface: surface, onRetryRestore: restorePurchases)
    }

    @ViewBuilder
    private var screenContent: some View {
        if showDeclineFeedback, let declineFeedbackContent {
            TrialDeclineFeedbackView(
                content: declineFeedbackContent,
                onResolve: { onResolved?() }
            )
            .transition(.opacity)
        } else if purchaseSucceeded && board.isTrialEnd {
            trialEndSuccessState
                .transition(.opacity)
        } else {
            HonestPaywallView(
                scene: scene,
                isPurchasing: isPurchasing,
                onSelect: selectPlan,
                onPurchase: purchase,
                onRestore: restorePurchases,
                onDismiss: onDismiss,
                onContinueFree: board.chrome.showsContinueFree ? { continueFree() } : nil
            )
            .transition(.opacity)
        }
    }

    private func selectPlan(_ intent: PaywallPurchaseIntent) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selection = intent
        }
        let plan = intent.pilliePlusPlan.analyticsPlan
        switch telemetryMode {
        case .trialEnd(let content):
            telemetry.trialEndPlanSelected(
                plan: plan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.paywallPlanSelected(
                plan: plan,
                isFromOnboarding: false,
                surface: surface
            )
        }
    }

    private func purchase(_ intent: PaywallPurchaseIntent) {
        guard let package = PaywallPurchaseBridge.package(for: intent, offerings: offerings) else {
            activeAlert = .purchaseError(CommercePresentation.offeringsUnavailableMessage(locale: locale))
            return
        }
        let plan = intent.pilliePlusPlan
        let response = plusFeedback.openPaywallOrStartPurchase(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(response.motionProfile.animation) { isPurchasing = true }
        // Captured before purchasing, as restore does: an active entitlement
        // ends the trial-end content and would drop the cohort.
        let mode = telemetryMode
        trackPurchaseStarted(plan: plan, mode: mode)

        Task {
            do {
                let outcome = try await subscriptionManager.purchase(package)
                trackPurchaseCompleted(plan: plan, mode: mode, outcome: outcome)
                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if board.isTrialEnd {
                    successOutcome = .purchased(plan)
                    purchaseSucceeded = true
                } else {
                    onDismiss()
                }
            } catch {
                plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if error.honestPaywallIsCancelledPurchase {
                    trackPurchaseCancelled(plan: plan, mode: mode)
                    await subscriptionManager.refreshStatus()
                } else {
                    trackPurchaseFailed(plan: plan, mode: mode, error: error)
                    activeAlert = .purchaseError(CommercePresentation.purchaseErrorMessage(error, locale: locale))
                }
            }
            withAnimation(response.motionProfile.animation) { isPurchasing = false }
        }
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        let response = plusFeedback.startRestore(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) { isRestoring = true }
        // Captured before restoring: a restored entitlement ends the trial-end
        // content, and the finished event must keep the cohort it started with.
        let mode = telemetryMode
        trackRestoreStarted(mode)

        Task {
            let outcome = await subscriptionManager.restore()
            trackRestoreFinished(outcome, mode: mode)
            switch outcome {
            case .restored:
                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if board.isTrialEnd {
                    successOutcome = .restored
                    purchaseSucceeded = true
                } else {
                    onDismiss()
                }
            case .noActivePurchase:
                withAnimation(response.motionProfile.animation) {
                    activeAlert = .noSubscription
                }
            case .failed:
                activeAlert = .restoreError
            }
            withAnimation(response.motionProfile.animation) { isRestoring = false }
        }
    }

    private func continueFree() {
        guard let routeContinueFree else {
            onDismiss()
            return
        }
        trackContinueFree()
        switch routeContinueFree() {
        case .enterFreeApp:
            onDismiss()
        case .presentFeedback:
            withAnimation(accessibilityReduceMotion ? nil : PillieTheme.fadeInUpCurve) {
                showDeclineFeedback = true
            }
        }
    }

    private func loadOfferings() async {
        do {
            offerings = try await subscriptionManager.fetchOfferings()
        } catch {
            telemetry.trackError(.offerings, error: error)
        }
    }

    // MARK: - Trial end success

    @ViewBuilder
    private var trialEndSuccessState: some View {
        let content = trialEndTelemetryContent
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(PillieTheme.coral.opacity(0.35))
                    .frame(width: 124, height: 124)
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
            }
            .accessibilityHidden(true)

            Text(PillieLocalization.string("trial.end.welcome_back", table: "Commerce", locale: locale))
                .font(.pillie(34, weight: .black))
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.top, 24)

            if let content {
                Text(CommercePresentation.trialEndSuccessSubtitle(cohort: content.cohort, locale: locale))
                    .font(.pillie(15, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 10)
            }

            Spacer()
            Spacer()

            Button(action: onDismiss) {
                Text(PillieLocalization.string("trial.end.back_today", table: "Commerce", locale: locale))
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(PillieTheme.dark)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var telemetryMode: HonestPaywallTelemetryMode {
        HonestPaywallTelemetry.mode(
            board: board,
            trialEndContent: trialEndTelemetryContent
        )
    }

    private var trialEndTelemetryContent: TrialEndPaywallContent? {
        TrialEndPaywallContent.make(
            state: subscriptionManager.plusAccessState,
            blockerConfigSaved: AppBlockingManager.shared.hasAppsSelected,
            stats: trialStats ?? .none,
            calendar: .current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
            termsCohort: subscriptionManager.trialTermsCohort
        )
    }

    // MARK: - Telemetry

    private func trackViewed() {
        switch telemetryMode {
        case .trialEnd(let content):
            telemetry.trialEndPaywallViewed(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.paywallViewed(surface: surface)
        }
    }

    private func trackPurchaseStarted(plan: PilliePlusPlan, mode: HonestPaywallTelemetryMode) {
        switch mode {
        case .trialEnd(let content):
            telemetry.trialEndPurchaseStarted(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.purchaseStarted(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
    }

    private func trackPurchaseCompleted(plan: PilliePlusPlan, mode: HonestPaywallTelemetryMode, outcome: PurchaseOutcome) {
        switch mode {
        case .trialEnd(let content):
            switch outcome.conversionEvent {
            case .trialStarted:
                telemetry.trialEndTrialStarted(
                    plan: plan.analyticsPlan,
                    cohort: content.cohort,
                    terms: content.terms,
                    termsCohort: content.termsCohort
                )
            case .purchaseCompleted:
                telemetry.trialEndPurchaseCompleted(
                    plan: plan.analyticsPlan,
                    cohort: content.cohort,
                    terms: content.terms,
                    termsCohort: content.termsCohort
                )
            case nil:
                break
            }
        case .surface:
            if outcome.conversionEvent == .purchaseCompleted {
                telemetry.purchaseCompleted(
                    plan: plan.analyticsPlan,
                    isFromOnboarding: false,
                    surface: surface
                )
            } else if outcome.conversionEvent == .trialStarted {
                telemetry.trialStarted(
                    plan: plan.analyticsPlan,
                    isFromOnboarding: false,
                    surface: surface
                )
            }
        }
    }

    private func trackPurchaseCancelled(plan: PilliePlusPlan, mode: HonestPaywallTelemetryMode) {
        switch mode {
        case .trialEnd(let content):
            telemetry.trialEndPurchaseCancelled(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.purchaseCancelled(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
    }

    private func trackPurchaseFailed(plan: PilliePlusPlan, mode: HonestPaywallTelemetryMode, error: Error) {
        switch mode {
        case .trialEnd(let content):
            telemetry.trialEndPurchaseFailed(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.purchaseFailed(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
        telemetry.trackError(.purchase, error: error)
    }

    private func trackRestoreStarted(_ mode: HonestPaywallTelemetryMode) {
        switch mode {
        case .trialEnd(let content):
            telemetry.trialEndRestoreStarted(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.restoreStarted(surface: surface)
        }
    }

    private func trackRestoreFinished(_ outcome: RestoreOutcome, mode: HonestPaywallTelemetryMode) {
        switch mode {
        case .trialEnd(let content):
            telemetry.trialEndRestoreFinished(
                outcome,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        case .surface:
            telemetry.restoreFinished(outcome, surface: surface)
        }
    }

    private func trackContinueFree() {
        guard case .trialEnd(let content) = telemetryMode else { return }
        telemetry.trialEndContinueFreeSelected(
            cohort: content.cohort,
            terms: content.terms,
            termsCohort: content.termsCohort
        )
    }
}

private extension Error {
    var honestPaywallIsCancelledPurchase: Bool {
        if let purchaseError = self as? SubscriptionPurchaseError,
           purchaseError == .userCancelled {
            return true
        }
        let nsError = self as NSError
        return nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1
    }
}
