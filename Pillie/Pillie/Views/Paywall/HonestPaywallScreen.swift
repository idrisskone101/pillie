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

    @State private var recurrence: PaywallRecurrence = .year
    @State private var offerings: Offerings?
    @State private var offeringsError = false
    @State private var purchaseError: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var purchaseSucceeded = false
    @State private var successOutcome: TrialEndSuccessOutcome = .purchased(.annual)
    @State private var showDeclineFeedback = false

    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    private var scene: HonestPaywallScene {
        HonestPaywallSceneBuilder.build(
            board: board,
            offerings: offerings.flatMap(PaywallOfferingsSnapshot.parse),
            recurrence: recurrence,
            locale: locale
        )
    }

    private var isTrialEnd: Bool {
        if case .trialEnded = board { return true }
        return false
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()
            coralWash
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
        .alert(
            PillieLocalization.string("paywall.purchase_error.title", table: "Commerce", locale: locale),
            isPresented: purchaseErrorPresented
        ) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) {
                purchaseError = nil
            }
        } message: {
            Text(purchaseError ?? "")
        }
        .alert(
            PillieLocalization.string("paywall.no_subscription.title", table: "Commerce", locale: locale),
            isPresented: $showNoSubscriptionAlert
        ) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) {}
        } message: {
            Text(PillieLocalization.string("paywall.no_subscription.body", table: "Commerce", locale: locale))
        }
    }

    private var purchaseErrorPresented: Binding<Bool> {
        Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )
    }

    @ViewBuilder
    private var screenContent: some View {
        if showDeclineFeedback, let declineFeedbackContent {
            TrialDeclineFeedbackView(
                content: declineFeedbackContent,
                onResolve: { onResolved?() }
            )
            .transition(.opacity)
        } else if purchaseSucceeded && isTrialEnd {
            trialEndSuccessState
                .transition(.opacity)
        } else {
            HonestPaywallView(
                scene: scene,
                isPurchasing: isPurchasing,
                onRecurrenceChange: selectRecurrence,
                onPurchase: purchase,
                onRestore: restorePurchases,
                onDismiss: onDismiss,
                onContinueFree: board.chrome.showsContinueFree ? { continueFree() } : nil
            )
            .transition(.opacity)
        }
    }

    private var coralWash: some View {
        Circle()
            .fill(PillieTheme.coral.opacity(0.28))
            .frame(width: 260, height: 260)
            .blur(radius: 60)
            .offset(x: 120, y: -80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func selectRecurrence(_ value: PaywallRecurrence) {
        withAnimation(.easeInOut(duration: 0.2)) {
            recurrence = value
        }
        telemetry.paywallPlanSelected(
            plan: value == .year ? .annual : .monthly,
            isFromOnboarding: false,
            surface: surface
        )
    }

    private func purchase(_ intent: PaywallPurchaseIntent) {
        guard let package = PaywallPurchaseBridge.package(for: intent, offerings: offerings) else {
            offeringsError = true
            return
        }
        let plan = intent.pilliePlusPlan
        let response = plusFeedback.openPaywallOrStartPurchase(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(response.motionProfile.animation) { isPurchasing = true }

        trackPurchaseStarted(plan: plan)

        Task {
            do {
                let outcome = try await subscriptionManager.purchase(package)
                trackPurchaseCompleted(plan: plan, outcome: outcome)
                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if isTrialEnd {
                    successOutcome = .purchased(plan)
                    purchaseSucceeded = true
                } else {
                    onDismiss()
                }
            } catch {
                plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if error.honestPaywallIsCancelledPurchase {
                    trackPurchaseCancelled(plan: plan)
                    await subscriptionManager.refreshStatus()
                } else {
                    trackPurchaseFailed(plan: plan, error: error)
                    purchaseError = CommercePresentation.purchaseErrorMessage(error, locale: locale)
                }
            }
            withAnimation(response.motionProfile.animation) { isPurchasing = false }
        }
    }

    private func restorePurchases() {
        let response = plusFeedback.startRestore(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) { isRestoring = true }
        trackRestoreStarted()

        Task {
            do {
                try await subscriptionManager.restore()
                if subscriptionManager.hasEntitlement {
                    trackRestoreCompleted()
                    plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    if isTrialEnd {
                        successOutcome = .restored
                        purchaseSucceeded = true
                    } else {
                        onDismiss()
                    }
                } else {
                    trackRestoreFailed()
                    withAnimation(response.motionProfile.animation) {
                        showNoSubscriptionAlert = true
                    }
                }
            } catch {
                trackRestoreFailed(error: error)
                purchaseError = CommercePresentation.restoreErrorMessage(error, locale: locale)
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
            offeringsError = false
        } catch {
            offeringsError = true
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

    private var trialEndTelemetryContent: TrialEndPaywallContent? {
        TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: subscriptionManager.hasEntitlement,
                trialGrantDate: subscriptionManager.trialGrantDate
            ),
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
        if let content = trialEndTelemetryContent {
            telemetry.trialEndPaywallViewed(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.paywallViewed(surface: surface)
        }
    }

    private func trackPurchaseStarted(plan: PilliePlusPlan) {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndPurchaseStarted(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.purchaseStarted(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
    }

    private func trackPurchaseCompleted(plan: PilliePlusPlan, outcome: PurchaseOutcome) {
        if let content = trialEndTelemetryContent {
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
        } else if outcome.conversionEvent == .purchaseCompleted {
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

    private func trackPurchaseCancelled(plan: PilliePlusPlan) {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndPurchaseCancelled(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.purchaseCancelled(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
    }

    private func trackPurchaseFailed(plan: PilliePlusPlan, error: Error) {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndPurchaseFailed(
                plan: plan.analyticsPlan,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.purchaseFailed(
                plan: plan.analyticsPlan,
                isFromOnboarding: false,
                surface: surface
            )
        }
        telemetry.trackError(.purchase, error: error)
    }

    private func trackRestoreStarted() {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndRestoreStarted(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.restoreStarted(isFromOnboarding: false, surface: surface)
        }
    }

    private func trackRestoreCompleted() {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndRestoreCompleted(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.restoreCompleted(isFromOnboarding: false, surface: surface)
        }
    }

    private func trackRestoreFailed(error: Error? = nil) {
        if let content = trialEndTelemetryContent {
            telemetry.trialEndRestoreFailed(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        } else {
            telemetry.restoreFailed(isFromOnboarding: false, surface: surface)
        }
        if let error {
            telemetry.trackError(.restore, error: error)
        }
    }

    private func trackContinueFree() {
        guard let content = trialEndTelemetryContent else { return }
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
