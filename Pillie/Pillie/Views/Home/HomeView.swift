// xcode: set sdk=iOS

//
//  HomeView.swift
//  Pillie
//

import SwiftUI
import StoreKit

struct HomeView: View {
    @Environment(PillStore.self) var store
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showRefillConfirmation = false
    @State private var showShakeConfirm = false
    @State private var showBlockingSetup = false
    @State private var showBlockingPaywall = false
    @State private var blockingPaywallSurface: AnalyticsPaywallSurface = .homeBlockingCard
    @State private var showTrialStatusSheet = false
    @State private var showTrialKeepPlusPaywall = false
    @State private var showTrialCustomMessagesEditor = false
    @State private var showTrialSmartRemindersEditor = false
    @State private var pendingTrialActivationAction: TrialActivationAction?
    @State private var trialEndPaywallPresentation = TrialEndPaywallPresentationState()
    #if DEBUG
    @State private var showDeveloperMenu = false
    #endif

    /// The presented Trial-End Paywall snapshot as an item binding: the cover and
    /// its content are one atomic unit, so the paywall can never present blank.
    private var trialEndPaywallItem: Binding<TrialEndPaywallContent?> {
        Binding(
            get: { trialEndPaywallPresentation.presentedContent },
            set: { newValue in
                if let newValue {
                    trialEndPaywallPresentation.present(newValue)
                } else {
                    trialEndPaywallPresentation.dismiss()
                }
            }
        )
    }
    @State private var showTrialDeclineThankYou = false
    @State private var reviewPromptShownLogged = false
    @AppStorage("homeBlockingStatusCardDismissed") private var blockingCardDismissed = false
    private let homeFeedback = HomeActionInteractionFeedback()
    private let trialDeclineFeedbackStore = KeychainTrialDeclineFeedbackResolutionStore()

    private var unifiedStateTransition: Animation {
        PillieMotion.animation(
            for: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    private var ctaStateTransition: AnyTransition {
        if accessibilityReduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Whether the home state is Reminder-Only Onboarding Completion (and which
    /// variant), derived live from entitlement + Screen Time + saved blocker config.
    /// Resolves to `.active` once Protection Plan Activation is reached, which hides
    /// the enable-blocking-later card.
    private var blockingPresentation: BlockingStatusPresentation {
        let blocking = AppBlockingManager.shared
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: SubscriptionManager.shared.hasPlusAccess,
                screenTimeAuthorized: blocking.authorizationStatus == .approved,
                // A non-empty saved selection — independent of the blocking pause toggle.
                blockerConfigSaved: blocking.hasAppsSelected
            )
        )
        return BlockingStatusPresentation.make(
            outcome: outcome,
            isEntitled: SubscriptionManager.shared.hasPlusAccess
        )
    }

    private func handleBlockingCardAction() {
        if SubscriptionManager.shared.hasPlusAccess {
            // Entitled but reminder-only: finish Screen Time setup directly.
            showBlockingSetup = true
        } else {
            // Free: go straight to the paywall (it reports paywallViewed itself).
            blockingPaywallSurface = .homeBlockingCard
            showBlockingPaywall = true
        }
    }

    /// Copy for the enable-blocking-later card, or `nil` when blocking is active or the
    /// card was dismissed — in which case it does not occupy this Home pass.
    private var blockingCardContent: BlockingStatusCardContent? {
        guard !blockingCardDismissed else { return nil }
        return BlockingStatusCardContent.make(for: blockingPresentation, locale: locale)
    }

    /// Copy + gating for the Protection Off State card (#167): Plus Access ended
    /// for a user with saved blocker config, so blocking stopped but the setup is
    /// preserved inert. Persistent — no dismissal state — until access returns.
    /// Its CTA reopens the Trial-End Paywall (#169); the Settings paywall remains
    /// the fallback for lapsed payers who never held a Reverse Trial.
    private var protectionOffContent: ProtectionOffCardContent? {
        ProtectionOffCardContent.make(
            hasPlusAccess: SubscriptionManager.shared.hasPlusAccess,
            blockerConfigSaved: AppBlockingManager.shared.hasAppsSelected,
            locale: locale
        )
    }

    /// The Trial-End Paywall's copy + cohort (#169), or `nil` when it must not
    /// exist: entitled, trial still active, or never granted. Derived live so
    /// the sheet can never outlive a purchase or show mid-trial.
    private var trialEndPaywallContent: TrialEndPaywallContent? {
        TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: SubscriptionManager.shared.hasEntitlement,
                trialGrantDate: SubscriptionManager.shared.trialGrantDate
            ),
            blockerConfigSaved: AppBlockingManager.shared.hasAppsSelected,
            stats: trialEndOwnStats,
            calendar: Calendar.current,
            now: trialEndEvaluationDate,
            locale: locale,
            hardPaywallEnabled: SubscriptionManager.shared.hardPaywallEnabled,
            termsCohort: SubscriptionManager.shared.trialTermsCohort
        )
    }

    private var trialEndEvaluationDate: Date {
        #if DEBUG
        SubscriptionManager.shared.debugTrialEndEvaluationDate ?? Date()
        #else
        Date()
        #endif
    }

    /// The user's own trial record for the loss-framed sheet. Raw optionals:
    /// a stat that cannot be read stays `nil` and drops its row (ADR 0002 —
    /// never a zero shown as a brag). The intercept counter is the lifetime
    /// total, which only ever accrues under Plus Access (#161).
    private var trialEndOwnStats: TrialEndOwnStats {
        guard let grantDate = SubscriptionManager.shared.trialGrantDate else { return .none }
        let calendar = Calendar.current
        let expiry = ReverseTrialClock(grantDate: grantDate).expiryMoment(calendar: calendar)
        let lastProtectedDay = calendar.date(byAdding: .day, value: -1, to: expiry) ?? expiry
        let record = store.doseRecord(from: grantDate, to: lastProtectedDay)
        return TrialEndOwnStats(
            blocksIntercepted: BlockerInterventionSharedState().counter.lifetimeTotal,
            dosesTaken: record.due > 0 ? record.taken : nil,
            dosesDue: record.due > 0 ? record.due : nil,
            currentStreak: store.currentStreak
        )
    }

    /// Auto-present the Trial-End Paywall exactly once, on the first Home pass
    /// at-or-after expiry (#169). The decision defers until RevenueCat resolves
    /// entitlement; the persisted flag makes it once-only — afterwards the
    /// Protection Off card is the way back.
    private func autoPresentTrialEndPaywallIfNeeded() {
        let manager = SubscriptionManager.shared
        guard TrialEndPaywallAutoPresentation.shouldPresent(
            state: PlusAccessState(
                hasEntitlement: manager.hasEntitlement,
                trialGrantDate: manager.trialGrantDate
            ),
            terms: trialEndPaywallContent?.terms ?? .legacy,
            termsCohort: trialEndPaywallContent?.termsCohort ?? .preCutover,
            entitlementResolved: manager.hasResolvedEntitlement,
            configurationResolved: manager.hasResolvedHardPaywallConfiguration,
            alreadyShown: UserDefaults.standard.bool(
                forKey: TrialEndPaywallAutoPresentation.shownStorageKey),
            rollbackAlreadyShown: UserDefaults.standard.bool(
                forKey: TrialEndPaywallAutoPresentation.rollbackShownStorageKey),
            calendar: Calendar.current,
            now: trialEndEvaluationDate
        ), trialEndPaywallContent != nil else { return }
        UserDefaults.standard.set(true, forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
        if trialEndPaywallContent?.terms == .legacy,
           trialEndPaywallContent?.termsCohort == .postCutover {
            UserDefaults.standard.set(
                true,
                forKey: TrialEndPaywallAutoPresentation.rollbackShownStorageKey
            )
        }
        if let content = trialEndPaywallContent {
            presentTrialEndPaywall(content)
        }
    }

    /// The Trial-End Paywall presentation must not be written synchronously from
    /// a body re-evaluation trigger (`.onAppear` / `.onChange` of the `@Observable`
    /// subscription state): a mid-update write is rolled back when the update
    /// finishes, which previously left the cover presenting a nil snapshot — a
    /// blank white screen. Deferring one tick lands the write in a clean update.
    private func presentTrialEndPaywall(_ content: TrialEndPaywallContent) {
        DispatchQueue.main.async {
            trialEndPaywallPresentation.present(content)
        }
    }

    private func routeTrialDeclineFeedback() -> TrialDeclineFeedbackRoute {
        let manager = SubscriptionManager.shared
        return TrialDeclineFeedbackRoute.evaluate(
            action: .continueFree,
            state: PlusAccessState(
                hasEntitlement: manager.hasEntitlement,
                trialGrantDate: manager.trialGrantDate
            ),
            entitlementResolved: manager.hasResolvedEntitlement,
            questionnaireResolved: trialDeclineFeedbackStore.isResolved(),
            calendar: Calendar.current,
            now: Date()
        )
    }

    private func resolveTrialDeclineFeedback() {
        trialDeclineFeedbackStore.markResolved()
        trialEndPaywallPresentation.dismiss()
        withAnimation(unifiedStateTransition) {
            showTrialDeclineThankYou = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(unifiedStateTransition) {
                showTrialDeclineThankYou = false
            }
        }
    }

    /// Whether a higher-priority Home "ask" card (Refill or Blocking) would render this
    /// pass. Feeds the Review Prompt's `higherPriorityCardShowing` input so the
    /// lowest-priority rating ask yields — at most one ask per Home visit (#132).
    private var higherPriorityCardShowing: Bool {
        protectionOffContent != nil || blockingCardContent != nil || store.isRefillDue
    }

    /// Copy + gating for the Home Review Prompt's Sentiment Gate card (#132). `nil` unless
    /// the user has reached Review Prompt Eligibility — an unbroken Streak past the
    /// method-aware threshold, never answered, not in cooldown or capped — and no
    /// higher-priority card is showing. Eligibility math lives entirely in
    /// `ReviewPromptEligibility` (on-device). Shown to free and Plus users alike.
    private var reviewPromptContent: ReviewPromptCardContent? {
        ReviewPromptCardContent.make(
            decision: store.reviewPromptDecision(higherPriorityCardShowing: higherPriorityCardShowing),
            locale: locale
        )
    }

    /// The in-trial indicator + status sheet surface (#166), or `nil` when no
    /// indicator should exist: entitled (a mid-trial purchase hides it on the
    /// next Home pass), expired, or never granted. Derived live so day counts
    /// and expiry can never drift from the Reverse Trial clock.
    private var trialPresentation: TrialStatusPresentation? {
        TrialStatusPresentation.make(
            state: PlusAccessState(
                hasEntitlement: SubscriptionManager.shared.hasEntitlement,
                trialGrantDate: SubscriptionManager.shared.trialGrantDate
            ),
            protectionActive: trialActivationState.appBlockingActive,
            calendar: Calendar.current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: SubscriptionManager.shared.hardPaywallEnabled,
            termsCohort: SubscriptionManager.shared.trialTermsCohort
        )
    }

    @MainActor
    private var trialActivationState: TrialActivationState {
        let blocking = AppBlockingManager.shared
        let customMessagesCustomized = [
            store.customDueReminderTitle,
            store.customDueReminderBody,
            store.customRetryReminderTitle,
            store.customRetryReminderBody,
            store.customLastCallReminderTitle,
            store.customLastCallReminderBody,
        ].contains(where: CustomReminderCopy.isCustomized)

        return TrialActivationState(
            appBlockingActive: blocking.authorizationStatus == .approved
                && blocking.isEffectivelyOn,
            customMessagesCustomized: customMessagesCustomized,
            smartRemindersCustomized: store.autoReminderIntervalMinutes != 10
                || store.autoReminderRetryLimit != 3
                || store.lastCallReminderEnabled
        )
    }

    private func handleTrialActivationTap(_ item: TrialActivationItem) {
        guard let action = item.action else { return }
        ProductAnalyticsTelemetry.live.trialStatusFeatureTapped(
            item.feature,
            status: item.status,
            isRecommended: item.isRecommended
        )
        pendingTrialActivationAction = action
        showTrialStatusSheet = false
    }

    private func presentPendingTrialActivationAction() {
        guard let action = pendingTrialActivationAction else { return }
        pendingTrialActivationAction = nil
        switch action {
        case .appBlocking:
            showBlockingSetup = true
        case .customMessages:
            showTrialCustomMessagesEditor = true
        case .smartReminders:
            showTrialSmartRemindersEditor = true
        }
    }

    private var todayActionState: TodayActionState {
        TodayActionState.resolve(
            TodayActionState.Input(
                isRefillDue: store.isRefillDue,
                isTodayTaken: store.isTodayTaken,
                todayDueAction: store.todayDueAction,
                isPlus: SubscriptionManager.shared.hasPlusAccess,
                reduceMotionEnabled: accessibilityReduceMotion
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PrimaryTitleAnchor(
                        title: PillieLocalization.string(
                            "today.navigation.title",
                            locale: locale
                        ),
                        titleFont: .pillieHeadline().weight(.bold),
                        showsAccessorySlot: true,
                        accessory: {
                            AnyView(
                                HStack {
                                    Text(dateString)
                                        .font(.pillieDate())
                                        .foregroundStyle(PillieTheme.textMuted)

                                    Spacer()

                                    #if DEBUG
                                    Button {
                                        showDeveloperMenu = true
                                    } label: {
                                        HomeAvatarLogoBadge()
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(verbatim: "Developer menu"))
                                    .accessibilityIdentifier("developerMenuAvatarButton")
                                    #else
                                    HomeAvatarLogoBadge()
                                    #endif
                                }
                            )
                        }
                    )
                        .modifier(FadeInUp(appeared: appeared, delay: 0))

                    if let trial = trialPresentation {
                        TrialIndicatorBadge(
                            label: trial.indicatorLabel,
                            onTap: {
                                ProductAnalyticsTelemetry.live.trialBadgeTapped()
                                showTrialStatusSheet = true
                            }
                        )
                        .modifier(FadeInUp(appeared: appeared, delay: 0.05))
                        .transition(ctaStateTransition)
                    }

                    StatusCard()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                    // At Accessibility Dynamic Type sizes the primary action belongs
                    // in the scroll flow. Keeping the regular floating treatment here
                    // would cover the expanded cards below it and squeeze the long
                    // localized label into the edge of the screen.
                    if dynamicTypeSize.isAccessibilitySize {
                        floatingButton
                            .modifier(FadeInUp(appeared: appeared, delay: 0.12))
                    }

                    if let protectionOff = protectionOffContent {
                        ProtectionOffCard(
                            content: protectionOff,
                            onPrimaryAction: {
                                // The Trial-End Paywall is this card's re-entry
                                // point after expiry (#169); the Settings paywall
                                // stays the fallback for lapsed payers with no
                                // expired trial. Each reports paywallViewed itself.
                                if let content = trialEndPaywallContent {
                                    presentTrialEndPaywall(content)
                                } else {
                                    blockingPaywallSurface = .protectionOffCard
                                    showBlockingPaywall = true
                                }
                            }
                        )
                        .modifier(FadeInUp(appeared: appeared, delay: 0.15))
                        .transition(ctaStateTransition)
                    }

                    if let blockingCard = blockingCardContent {
                        BlockingStatusCard(
                            content: blockingCard,
                            onPrimaryAction: { handleBlockingCardAction() },
                            onDismiss: {
                                withAnimation(unifiedStateTransition) { blockingCardDismissed = true }
                            }
                        )
                        .modifier(FadeInUp(appeared: appeared, delay: 0.15))
                        .transition(ctaStateTransition)
                    }

                    if store.isRefillDue {
                        RefillBannerCard(onRefill: {
                            showRefillConfirmation = true
                            ProductAnalyticsTelemetry.live.newPackOrCyclePrompted()
                        })
                        .modifier(FadeInUp(appeared: appeared, delay: 0.15))
                    }

                    PillPackCard()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.2))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)

                    StatsRow()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)

                    if let reviewContent = reviewPromptContent {
                        ReviewPromptCard(
                            content: reviewContent,
                            onPositive: { handleReviewPromptPositive() },
                            onNegative: { handleReviewPromptNegative() },
                            onDismiss: {
                                withAnimation(unifiedStateTransition) {
                                    store.softDismissReviewPrompt()
                                }
                                ProductAnalyticsTelemetry.live.reviewPromptDismissed()
                            }
                        )
                        .onAppear {
                            guard !reviewPromptShownLogged else { return }
                            reviewPromptShownLogged = true
                            ProductAnalyticsTelemetry.live.reviewPromptShown()
                        }
                        .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                        .transition(ctaStateTransition)
                    }

                    // Handwriting motivation
                    Text(PillieLocalization.string("today.greeting", locale: locale))
                        .font(.pillieHandwriting())
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .rotationEffect(.degrees(-2))
                        .padding(.top, 8)
                        .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, PillieTheme.scrollTopPadding)
                .padding(
                    .bottom,
                    dynamicTypeSize.isAccessibilitySize
                        ? PillieTheme.scrollBottomPaddingDefault
                        : PillieTheme.scrollBottomPaddingWithCTA
                )
            }

            // The compact layout keeps the action persistently reachable. At large
            // accessibility sizes it is rendered above in document order instead.
            if !dynamicTypeSize.isAccessibilitySize {
                floatingButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
            }
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showTrialDeclineThankYou {
                TrialDeclineThankYouBanner(
                    message: TrialDeclineFeedbackContent.make(locale: locale).thankYou
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(
                    accessibilityReduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity)
                )
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            autoPresentTrialEndPaywallIfNeeded()
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        // Entitlement usually resolves after the first render; the auto-present
        // decision defers until it has (#169), so re-run the check then — and
        // when the grant date changes (QA deep links age or clear the trial).
        .onChange(of: SubscriptionManager.shared.hasResolvedEntitlement) { _, _ in
            autoPresentTrialEndPaywallIfNeeded()
        }
        .onChange(of: SubscriptionManager.shared.hasResolvedHardPaywallConfiguration) { _, _ in
            autoPresentTrialEndPaywallIfNeeded()
        }
        .onChange(of: SubscriptionManager.shared.trialGrantDate) { _, _ in
            autoPresentTrialEndPaywallIfNeeded()
        }
        .onChange(of: SubscriptionManager.shared.hasPlusAccess) { previous, current in
            guard TrialEndPaywallAutoPresentation.shouldReevaluate(
                previousPlusAccess: previous,
                currentPlusAccess: current
            ) else { return }
            autoPresentTrialEndPaywallIfNeeded()
        }
        .alert(startNewConfirmation.title, isPresented: $showRefillConfirmation) {
            Button(PillieLocalization.string(
                "today.pack.start_new.confirm",
                locale: locale
            )) {
                startNewPackOrCycle()
                ProductAnalyticsTelemetry.live.newPackOrCycleStarted()
            }
            Button(PillieLocalization.string("global.action.not_now", locale: locale), role: .cancel) {}
        } message: {
            Text(startNewConfirmation.body)
        }
        .sheet(isPresented: $showBlockingSetup) {
            BlockedAppsEditor()
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .fullScreenCover(isPresented: $showBlockingPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                paywallSurface: blockingPaywallSurface,
                onBack: { showBlockingPaywall = false },
                onContinue: { showBlockingPaywall = false },
                onSkip: { showBlockingPaywall = false }
            )
        }
        .sheet(
            isPresented: $showTrialStatusSheet,
            onDismiss: presentPendingTrialActivationAction
        ) {
            if let trial = trialPresentation {
                TrialStatusSheet(
                    content: trial.sheetContent(for: trialActivationState),
                    onKeepPlus: {
                        // The quiet buy-early path: into the existing purchase
                        // flow (it reports paywallViewed itself).
                        showTrialStatusSheet = false
                        showTrialKeepPlusPaywall = true
                    },
                    onFeatureTap: handleTrialActivationTap,
                    onDismiss: { showTrialStatusSheet = false }
                )
                .onAppear {
                    ProductAnalyticsTelemetry.live.trialStatusSheetViewed()
                }
                .presentationDetents([.height(TrialStatusSheet.presentationHeight)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
            }
        }
        .sheet(isPresented: $showTrialCustomMessagesEditor) {
            CustomReminderMessagesEditor(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showTrialSmartRemindersEditor) {
            AutoReminderIntervalEditor(store: store)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .fullScreenCover(
            item: trialEndPaywallItem,
            onDismiss: { trialEndPaywallPresentation.dismiss() }
        ) { content in
            TrialEndPaywallView(
                content: content,
                declineFeedbackContent: .make(locale: locale),
                routeContinueFree: routeTrialDeclineFeedback,
                onDismiss: { trialEndPaywallPresentation.dismiss() },
                onFeedbackResolved: resolveTrialDeclineFeedback
            )
        }
        .fullScreenCover(isPresented: $showTrialKeepPlusPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                paywallSurface: .trialStatus,
                onBack: { showTrialKeepPlusPaywall = false },
                onContinue: { showTrialKeepPlusPaywall = false },
                onSkip: { showTrialKeepPlusPaywall = false }
            )
        }
        .fullScreenCover(isPresented: $showShakeConfirm) {
            if let action = store.todayDueAction {
                ShakeConfirmView(
                    action: action,
                    onConfirm: {
                        completeTodayAction()
                        showShakeConfirm = false
                    },
                    onDismiss: {
                        showShakeConfirm = false
                    }
                )
            }
        }
        #if DEBUG
        .sheet(isPresented: $showDeveloperMenu) {
            DeveloperMenuView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pillieDebugQADidApply)) { _ in
            trialEndPaywallPresentation.dismiss()
            DispatchQueue.main.async {
                autoPresentTrialEndPaywallIfNeeded()
            }
        }
        #endif
    }

    // MARK: - Floating Button

    @ViewBuilder
    private var floatingButton: some View {
        let state = todayActionState
        Group {
            switch state {
            case .refillDue:
                Button {
                    showRefillConfirmation = true
                    ProductAnalyticsTelemetry.live.newPackOrCyclePrompted()
                } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityFloatingButtonLabel(
                                state.localizedPrimaryLabel(locale: locale)
                            )
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(state.localizedPrimaryLabel(locale: locale))
                            }
                        }
                    }
                }
                .buttonStyle(.pillieDark)
                .transition(ctaStateTransition)
            case .completed:
                Button {
                    let feedbackResponse = homeFeedback.undoTodayAction(
                        accessibilityReduceMotion: accessibilityReduceMotion
                    )
                    withAnimation(feedbackResponse.motionProfile.animation) {
                        store.unmarkTodayAsTaken()
                    }
                    ProductAnalyticsTelemetry.live.todayActionUndone()
                } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityFloatingButtonLabel(
                                state.localizedPrimaryLabel(locale: locale)
                            )
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(state.localizedPrimaryLabel(locale: locale))
                            }
                        }
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .transition(ctaStateTransition)
            case .noActionDue:
                Button {
                    // No due action for today.
                } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityFloatingButtonLabel(
                                state.localizedPrimaryLabel(locale: locale)
                            )
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(state.localizedPrimaryLabel(locale: locale))
                            }
                        }
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .allowsHitTesting(false)
                .transition(ctaStateTransition)
            case .dueAction(_, let requiresShakeConfirm):
                Button {
                    ProductAnalyticsTelemetry.live.todayActionStarted()
                    if requiresShakeConfirm {
                        showShakeConfirm = true
                    } else {
                        completeTodayAction()
                    }
                } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityFloatingButtonLabel(
                                state.localizedPrimaryLabel(locale: locale)
                            )
                        } else {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    )
                                Text(state.localizedPrimaryLabel(locale: locale))
                            }
                        }
                    }
                }
                .buttonStyle(.pillieDark)
                .transition(ctaStateTransition)
            }
        }
        .animation(unifiedStateTransition, value: store.isTodayTaken)
        .animation(unifiedStateTransition, value: store.isRefillDue)
        .animation(unifiedStateTransition, value: store.todayDueAction == nil)
    }

    private func accessibilityFloatingButtonLabel(_ label: String) -> some View {
        Text(label)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .allowsTightening(true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var dateString: String {
        Date().formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(locale)
        )
    }

    private var startNewConfirmation: CycleNounPresentation.StartNewConfirmation {
        CycleNounPresentation.startNewConfirmation(
            for: store.pack.method,
            locale: locale
        )
    }

    private func completeTodayAction() {
        let feedbackResponse = homeFeedback.commitTodayAction(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.markTodayAsTaken()
        }
        ProductAnalyticsTelemetry.live.todayActionCompleted()
    }

    /// Positive Sentiment Gate response: fire Apple's Native Review Request immediately
    /// (the system sheet animates over the card) and permanently suppress the prompt in
    /// the same action. Pillie never waits to confirm the sheet appeared or that a rating
    /// was left — every fire is best-effort (#132 / ADR 0005).
    private func handleReviewPromptPositive() {
        requestReview()
        withAnimation(unifiedStateTransition) {
            store.recordReviewPromptAnswered()
        }
        ProductAnalyticsTelemetry.live.reviewPromptPositiveTapped()
    }

    /// Negative Sentiment Gate response: open the Feedback Escape Hatch — a pre-filled,
    /// pre-addressed Mail composer to Pillie support — and permanently suppress the
    /// prompt. A device with no Mail account is tolerated (the prompt is still marked
    /// answered) and never blocked on. The feedback text is private and never reported.
    private func handleReviewPromptNegative() {
        if let mailURL = FeedbackEscapeHatch.mailURL(locale: locale) {
            openURL(mailURL)
        }
        withAnimation(unifiedStateTransition) {
            store.recordReviewPromptAnswered()
        }
        ProductAnalyticsTelemetry.live.reviewPromptNegativeTapped()
    }

    private func startNewPackOrCycle() {
        let feedbackResponse = homeFeedback.commitNewPackOrCycle(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.startNewPack()
        }
    }
}

// MARK: - Taken Button Style

private struct PillieTakenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(18, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .pillieAdaptiveLineLimit(minimumScaleFactor: 0.65)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.sage)
            .clipShape(Capsule())
    }
}

private struct TrialDeclineThankYouBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PillieTheme.verifiedGreen)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(PillieTheme.dark, in: Capsule())
        .shadow(color: PillieTheme.dark.opacity(0.22), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trialDeclineFeedbackThankYou")
    }
}

#Preview {
    HomeView()
        .environment(PillStore.previewStore())
}
