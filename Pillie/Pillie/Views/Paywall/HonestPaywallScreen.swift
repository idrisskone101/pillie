//
//  HonestPaywallScreen.swift
//  Pillie
//

import SwiftUI
import RevenueCat

struct HonestPaywallScreen: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store

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
    @State private var success: PaywallSuccessContent?
    @State private var showDeclineFeedback = false
    @State private var extendCandidate: TrialEndExtendCandidate?
    @State private var extendOffer: TrialEndExtendOffer?
    @State private var showsExtendOffer = false
    @State private var extendTelemetryMode: HonestPaywallTelemetryMode?
    /// Set once offerings and the extend candidate are in, so a win-back open
    /// that lands mid-load waits for the end of `.task` instead.
    @State private var isReadyForWinbackOpen = false

    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)
    private let extendOfferStore: TrialEndExtendOfferStoring = KeychainTrialEndExtendOfferStore()
    private let notificationPermission = NotificationPermission.shared
    private let winbackRouter = WinbackRouter.shared

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
        .animation(PillieTheme.fadeInUpCurve, value: showDeclineFeedback)
        .onAppear {
            trackViewed()
        }
        .task {
            subscriptionManager.configure()
            async let offeringsLoaded: Void = loadOfferings()
            async let permissionLoaded: Void = notificationPermission.refresh()
            await subscriptionManager.refreshStatus()
            await offeringsLoaded
            await prefetchExtendCandidate()
            await permissionLoaded
            isReadyForWinbackOpen = true
            await consumeWinbackOpen()
            #if DEBUG
            presentDebugExtendOfferIfRequested()
            await presentDebugSuccessIfRequested()
            #endif
        }
        .onChange(of: winbackRouter.pendingOpen) { _, open in
            // The tap brought the app back with the wall already up.
            guard open != nil, isReadyForWinbackOpen else { return }
            Task { await consumeWinbackOpen() }
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
                    isSheetAway: showsExtendOffer || success != nil,
                    phoneShield: success.map { .plusOn(line: $0.phoneLine) } ?? .paused
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

                if let success {
                    PaywallSuccessSheet(content: success, onDone: onDismiss)
                        .transition(PaywallSuccessSheet.transition(reduceMotion: accessibilityReduceMotion))
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
                presentSuccess(.purchased(plan: plan, product: package.storeProduct, outcome: outcome))
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
                presentSuccess(.restored)
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
              extendOfferStore.loadPhase().offers,
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
        recordWinbackPitch(trigger)
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

    /// Slot 3 of the win-back pushes (ENG-173) promises this card, so it waits
    /// until the wall has seen an SKU Apple would actually give her. Recorded
    /// before the phase gate: a card she already declined can still come back
    /// once from the push.
    private func recordWinbackPitch(_ trigger: TrialEndExtendTrigger) {
        guard board.isTrialEnd,
              let extendCandidate,
              extendCandidate.eligibility == .eligible
        else { return }
        let pitch = WinbackExtendPitch(trigger: trigger, priceDisplay: extendCandidate.product.priceDisplay)
        guard pitch != WinbackExtendPitch.load() else { return }
        pitch.save()
        NotificationManager.shared.requestReschedule(from: store, reason: "winback-extend-pitch")
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
                let outcome = try await subscriptionManager.purchase(package)
                extendOfferStore.record(.accept)
                trackExtend(offer.trigger, telemetry.trialEndExtendOfferAccepted)
                // The wall's convert funnel counts trial starts, so the free
                // week has to land there too.
                if let extendTelemetryMode {
                    trackPurchaseCompleted(plan: .annual, mode: extendTelemetryMode, outcome: outcome)
                }
                scheduleExtendReminder(for: offer)
                presentSuccess(.purchased(plan: .annual, product: package.storeProduct, outcome: outcome))
            } catch {
                plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if error.honestPaywallIsCancelledPurchase {
                    // Backing out of Apple's sheet for the free week counts as
                    // a no: only the slot 3 win-back push can bring it back.
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
        // reach it below the plans.
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

    // MARK: - Win-back open (ENG-173)

    /// A tapped win-back push lands here once the wall is loaded. Slot 3
    /// re-arms the extend card for its one second chance; when Apple says no
    /// or serves no SKU, the plans stay, which is the right fallback.
    private func consumeWinbackOpen() async {
        guard board.isTrialEnd, let open = winbackRouter.takePendingOpen() else { return }
        let mode = telemetryMode
        if case .trialEnd(let content) = mode {
            telemetry.trialEndPaywallViewed(
                fromWinback: open,
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
        }
        guard open.slot == .extendOffer else { return }
        extendOfferStore.record(.rearm)
        await prefetchExtendCandidate()
        presentExtendOffer(open.variant == .restore ? .restoreEmpty : .sheetCancel, mode: mode)
    }

    // MARK: - Success

    /// Every purchase and restore lands here. The success haptic fires when the
    /// phone's check badge lands, not on StoreKit's return.
    private func presentSuccess(_ receipt: PaywallSuccessReceipt) {
        let now = Date()
        showsExtendOffer = false
        let content = PaywallSuccessContent.make(
            receipt: receipt,
            isReturning: board.isTrialEnd || receipt == .restored,
            opensFromSettings: surface == .settingsSubscription,
            reminder: .live(store: store, now: now, calendar: .current),
            blockingSetUp: AppBlockingManager.shared.hasAppsSelected,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            now: now,
            calendar: .current,
            locale: locale
        )
        withAnimation(PaywallSuccessSheet.entrance(reduceMotion: accessibilityReduceMotion)) {
            success = content
        }
    }

    #if DEBUG
    /// `success=annual|monthly|lifetime|restored|trial` on the paywall QA links:
    /// play the success screen once the paywall's entrance has settled.
    private func presentDebugSuccessIfRequested() async {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: Self.debugSuccessStateKey) else { return }
        defaults.removeObject(forKey: Self.debugSuccessStateKey)
        try? await Task.sleep(for: .seconds(1.2))
        presentSuccess(.debugSample(raw))
    }
    #endif

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
            // A win-back tap reports this view itself, with its slot.
            guard winbackRouter.freshPendingOpen() == nil else { return }
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
