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
    @State private var extendCandidate: TrialEndExtendCandidate?
    @State private var extendOffer: TrialEndExtendOffer?
    @State private var showsExtendOffer = false
    @State private var extendTelemetryMode: HonestPaywallTelemetryMode?

    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)
    private let extendOfferStore: TrialEndExtendOfferStoring = KeychainTrialEndExtendOfferStore()
    private let notificationPermission = NotificationPermission.shared

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
            async let permissionLoaded: Void = notificationPermission.refresh()
            await subscriptionManager.refreshStatus()
            await offeringsLoaded
            await prefetchExtendCandidate()
            await permissionLoaded
            #if DEBUG
            presentDebugExtendOfferIfRequested()
            #endif
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
            ZStack {
                HonestPaywallView(
                    scene: scene,
                    isPurchasing: isPurchasing && !showsExtendOffer,
                    onSelect: selectPlan,
                    onPurchase: purchase,
                    onRestore: restorePurchases,
                    onDismiss: onDismiss,
                    onContinueFree: board.chrome.showsContinueFree ? { continueFree() } : nil,
                    isSheetAway: showsExtendOffer
                )

                if let extendOffer {
                    TrialEndExtendOfferSheet(
                        card: TrialEndExtendOfferCard.make(
                            offer: extendOffer,
                            remindersAllowed: notificationPermission.remindersAllowed,
                            calendar: .current,
                            locale: locale
                        ),
                        isPresented: showsExtendOffer,
                        isPurchasing: isPurchasing,
                        onStart: startExtendTrial,
                        onNotNow: declineExtendOffer
                    )
                }
            }
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
                    presentExtendOffer(.sheetCancel, mode: mode)
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
                if !presentExtendOffer(.restoreEmpty, mode: mode) {
                    withAnimation(response.motionProfile.animation) {
                        activeAlert = .noSubscription
                    }
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

    // MARK: - Extend offer (ENG-172)

    /// Read ahead of any cancel, so the card can rise the moment StoreKit
    /// returns instead of waiting on an eligibility round trip.
    private func prefetchExtendCandidate() async {
        guard board.isTrialEnd,
              extendOfferStore.loadPhase() == .unseen,
              let package = PaywallPurchaseBridge.extendPackage(offerings: offerings),
              let product = TrialEndExtendProduct(storeProduct: package.storeProduct),
              product.freeDays == TrialEndExtendOfferCard.supportedFreeDays
        else { return }
        let eligibility = await subscriptionManager.extendOfferEligibility(for: package.storeProduct)
        extendCandidate = TrialEndExtendCandidate(package: package, product: product, eligibility: eligibility)
    }

    /// Shows the one-time card in place of the plans. Returns false when any
    /// gate withholds it, so the caller keeps its usual outcome.
    @discardableResult
    private func presentExtendOffer(_ trigger: TrialEndExtendTrigger, mode: HonestPaywallTelemetryMode) -> Bool {
        guard let extendCandidate,
              let offer = TrialEndExtendOfferDecision.offer(
                  trigger: trigger,
                  isTrialEndBoard: board.isTrialEnd,
                  phase: extendOfferStore.loadPhase(),
                  eligibility: extendCandidate.eligibility,
                  product: extendCandidate.product,
                  now: Date(),
                  calendar: .current
              )
        else { return false }
        extendOfferStore.record(.present)
        extendTelemetryMode = mode
        extendOffer = offer
        showsExtendOffer = true
        if case .trialEnd(let content) = mode {
            telemetry.trialEndExtendOfferShown(
                trigger: trigger,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        }
        return true
    }

    private func startExtendTrial() {
        guard let offer = extendOffer, let package = extendCandidate?.package else {
            activeAlert = .purchaseError(CommercePresentation.offeringsUnavailableMessage(locale: locale))
            return
        }
        let response = plusFeedback.openPaywallOrStartPurchase(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(response.motionProfile.animation) { isPurchasing = true }

        Task {
            do {
                try await subscriptionManager.purchase(package)
                extendOfferStore.record(.accept)
                trackExtend(offer.trigger, telemetry.trialEndExtendOfferAccepted)
                scheduleExtendReminder(for: offer)
                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                successOutcome = .purchased(.annual)
                purchaseSucceeded = true
            } catch {
                plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if error.honestPaywallIsCancelledPurchase {
                    // Backing out of Apple's sheet for the free week spends the
                    // one time too: the card never comes back after a no.
                    declineExtendOffer()
                } else {
                    telemetry.trackError(.purchase, error: error)
                    activeAlert = .purchaseError(CommercePresentation.purchaseErrorMessage(error, locale: locale))
                }
            }
            withAnimation(response.motionProfile.animation) { isPurchasing = false }
        }
    }

    private func declineExtendOffer() {
        guard let offer = extendOffer, showsExtendOffer else { return }
        extendOfferStore.record(.decline)
        trackExtend(offer.trigger, telemetry.trialEndExtendOfferDismissed)
        showsExtendOffer = false
        // Drop the card once it has fallen off screen, so VoiceOver cannot
        // reach it below the plans. It can never be shown again anyway.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            extendOffer = nil
        }
    }

    /// The timeline is rebuilt from the purchase moment: Apple starts the free
    /// week when she confirms, which can be a day after the card rose.
    private func scheduleExtendReminder(for offer: TrialEndExtendOffer) {
        guard let timeline = TrialEndExtendTimeline(
            start: Date(),
            freeDays: offer.product.freeDays,
            calendar: .current
        ) else { return }
        NotificationManager.shared.scheduleTrialEndExtendReminder(
            for: TrialEndExtendOffer(trigger: offer.trigger, product: offer.product, timeline: timeline)
        )
    }

    private func trackExtend(
        _ trigger: TrialEndExtendTrigger,
        _ event: (TrialEndExtendTrigger, TrialEndPaywallCohort, TrialEndAccessTerms, TrialTermsCohort?) -> Void
    ) {
        guard case .trialEnd(let content) = extendTelemetryMode else { return }
        event(trigger, content.cohort, content.terms, content.termsCohort)
    }

    #if DEBUG
    /// `pillie://debug/trial-end-extend`: rise straight into the card. The
    /// RevenueCat Test Store serves no extend SKU, so a $29.99 week stands in.
    private func presentDebugExtendOfferIfRequested() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: Self.debugExtendTriggerKey) else { return }
        defaults.removeObject(forKey: Self.debugExtendTriggerKey)
        let trigger: TrialEndExtendTrigger = raw == "restore" ? .restoreEmpty : .sheetCancel
        extendCandidate = TrialEndExtendCandidate(
            package: extendCandidate?.package,
            product: extendCandidate?.product ?? TrialEndExtendProduct(
                productID: SubscriptionManager.extendAnnualProductID,
                priceDisplay: "$29.99",
                freeDays: TrialEndExtendOfferCard.supportedFreeDays
            ),
            eligibility: .eligible
        )
        presentExtendOffer(trigger, mode: telemetryMode)
    }
    #endif

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

/// The extend SKU as served, read before any cancel. `package` is nil only
/// for the DEBUG fixture, which can be shown but not bought.
private struct TrialEndExtendCandidate {
    let package: Package?
    let product: TrialEndExtendProduct
    let eligibility: TrialEndExtendEligibility
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
