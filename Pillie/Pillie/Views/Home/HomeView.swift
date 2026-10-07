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
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showRefillConfirmation = false
    @State private var showShakeConfirm = false
    /// The log the shake cover confirms, kept while it closes: a late log clears `openCatchUp` at once.
    @State private var shakeLog: PillStore.TodayLog?
    /// Holds the pack card's pop until the shake cover has slid away, so the log is seen landing.
    @State private var holdsPackCardLog = false
    @State private var shakeStreakChange = StreakChange.none
    @State private var showBlockingSetup = false
    @State private var showBlockingPaywall = false
    @State private var blockingPaywallSurface: AnalyticsPaywallSurface = .homeBlockingCard
    @State private var showTrialStatusSheet = false
    @State private var showTrialKeepPlusPaywall = false
    @State private var showPlusSetup = false
    @State private var trialEndPaywallPresentation = TrialEndPaywallPresentationState()
    #if DEBUG
    @State private var showDeveloperMenu = false
    /// A QA deep link landed while the Trial-End Paywall was up: present the
    /// new scenario's wall once the old cover finishes dismissing.
    @State private var debugRepresentsTrialEndPaywall = false
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
    @AppStorage(PlusSetupProgress.finishedStorageKey) private var plusSetupFinished = false
    @Bindable private var blockingManager = AppBlockingManager.shared
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
        return BlockingStatusCardContent.make(
            for: blockingPresentation,
            heldForPlusSetup: PlusSetupProgress.holdsBlockingCard(
                trialDay: trialPresentation?.currentDay,
                finished: plusSetupFinished
            ),
            method: store.pack.method,
            action: store.dueAction(on: store.today),
            locale: locale
        )
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
            state: SubscriptionManager.shared.plusAccessState,
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
        guard let clock = SubscriptionManager.shared.plusAccessState.trialClock else { return .none }
        let calendar = Calendar.current
        let expiry = clock.expiryMoment(calendar: calendar)
        let lastProtectedDay = calendar.date(byAdding: .day, value: -1, to: expiry) ?? expiry
        let record = store.doseRecord(from: clock.grantDate, to: lastProtectedDay)
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
            state: manager.plusAccessState,
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
            state: manager.plusAccessState,
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
            state: SubscriptionManager.shared.plusAccessState,
            protectionActive: plusSetupProgress.isDone(.blocking),
            calendar: Calendar.current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: SubscriptionManager.shared.hardPaywallEnabled,
            termsCohort: SubscriptionManager.shared.trialTermsCohort
        )
    }

    private var plusSetupProgress: PlusSetupProgress {
        PlusSetupProgress.live(store: store)
    }

    private var firstReminderLabel: String {
        store.firstReminderHandoff?.localizedLine(locale: locale) ?? ""
    }

    /// The "Took it" chip's action while Today waits on the first reminder.
    private var logBeforeFirstReminder: (() -> Void)? {
        guard case .dueActionAwaitingFirstReminder(_, let requiresShakeConfirm) = todayActionState
        else { return nil }
        return { startTodayAction(requiresShakeConfirm: requiresShakeConfirm) }
    }

    private var todayActionState: TodayActionState {
        TodayActionState.resolve(
            TodayActionState.Input(
                isRefillDue: store.isRefillDue,
                isTodayTaken: store.isTodayTaken,
                todayDueAction: store.todayDueAction,
                isPlus: SubscriptionManager.shared.hasPlusAccess,
                reduceMotionEnabled: accessibilityReduceMotion,
                catchUp: store.openCatchUp,
                isCaughtUpToday: store.isCaughtUpToday,
                awaitsFirstReminder: store.firstReminderHandoff?.isComing == true
            )
        )
    }

    private var greeting: String { PillieLocalization.string("today.greeting", locale: locale) }

    var body: some View {
        let _ = store.protocolChangeVersion
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

                    if plusSetupProgress.showsStrip(
                        inTrial: trialPresentation != nil,
                        finished: plusSetupFinished
                    ) {
                        PlusSetupStrip(progress: plusSetupProgress) {
                            ProductAnalyticsTelemetry.live.plusSetupStripTapped(
                                completedCount: plusSetupProgress.completedCount
                            )
                            showPlusSetup = true
                        }
                        .onAppear {
                            ProductAnalyticsTelemetry.live.plusSetupStripViewed(
                                completedCount: plusSetupProgress.completedCount
                            )
                        }
                        .modifier(FadeInUp(appeared: appeared, delay: 0.12))
                        .transition(ctaStateTransition)
                    }

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

                    Group {
                        if let method = RoutineDialMethod(store.pack.method) {
                            HomeCountdownCard(method: method, holdsTodayLog: holdsPackCardLog)
                        } else {
HomePackCard(holdsTodayLog: holdsPackCardLog)
                        }
                    }
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
                    Text(greeting)
                        .font(.pillieHandwriting(for: greeting))
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
            StreakChangeReport.record(store)
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        // Coming back from Settings can turn notifications on or off.
        .task(id: scenePhase) {
            await NotificationPermission.shared.refresh()
        }
        // The day rolling over bumps this too; logs, undos and pack changes report their own reason first.
        .onChange(of: store.protocolChangeVersion) { _, _ in
            StreakChangeReport.record(store)
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
            HonestPaywallHost(
                entry: blockingPaywallSurface.paywallEntry,
                surface: blockingPaywallSurface,
                onDismiss: { showBlockingPaywall = false }
            )
        }
        .sheet(isPresented: $showTrialStatusSheet) {
            if let trial = trialPresentation {
                TrialStatusSheet(
                    content: trial.sheetContent,
                    onKeepPlus: {
                        // The quiet buy-early path: into the existing purchase
                        // flow (it reports paywallViewed itself).
                        showTrialStatusSheet = false
                        showTrialKeepPlusPaywall = true
                    },
                    onDismiss: { showTrialStatusSheet = false }
                )
                .onAppear {
                    ProductAnalyticsTelemetry.live.trialStatusSheetViewed()
                }
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
            }
        }
        .fullScreenCover(
            item: trialEndPaywallItem,
            onDismiss: {
                trialEndPaywallPresentation.dismiss()
                #if DEBUG
                if debugRepresentsTrialEndPaywall {
                    debugRepresentsTrialEndPaywall = false
                    autoPresentTrialEndPaywallIfNeeded()
                }
                #endif
            }
        ) { _ in
            HonestPaywallHost(
                entry: .trialEndAutoPresent,
                surface: .trialEnd,
                trialStats: trialEndOwnStats,
                declineFeedbackContent: .make(locale: locale),
                routeContinueFree: routeTrialDeclineFeedback,
                onDismiss: { trialEndPaywallPresentation.dismiss() },
                onResolved: resolveTrialDeclineFeedback
            )
        }
        .sheet(isPresented: $showPlusSetup) {
            PlusSetupSheet(opening: .opening(for: plusSetupProgress))
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
                .presentationCornerRadius(PillieTheme.cardRadius)
        }
        .fullScreenCover(isPresented: $showTrialKeepPlusPaywall) {
            HonestPaywallHost(
                entry: .trialStatus,
                surface: .trialStatus,
                onDismiss: { showTrialKeepPlusPaywall = false }
            )
        }
        .fullScreenCover(isPresented: $showShakeConfirm, onDismiss: {
            holdsPackCardLog = false
            shakeLog = nil
        }) {
            if let shown = shakeLog ?? store.todayLog {
                ShakeConfirmView(
                    action: shown.action,
                    streak: shakeStreakChange,
                    onConfirm: {
                        completeTodayAction(shown: shown)
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
            // Re-presenting before the cover's dismissal finishes lets its
            // late onDismiss clear the new wall, so wait for onDismiss.
            guard trialEndPaywallPresentation.presentedContent == nil else {
                debugRepresentsTrialEndPaywall = true
                trialEndPaywallPresentation.dismiss()
                return
            }
            DispatchQueue.main.async {
                autoPresentTrialEndPaywallIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pillieDebugPresentHonestPaywall)) { note in
            switch note.object as? String {
            case "duringTrial", "c1":
                showTrialKeepPlusPaywall = true
            case "settingsFree", "c3":
                blockingPaywallSurface = .homeBlockingCard
                showBlockingPaywall = true
            default:
                break
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
                        if store.isTodayTaken {
                            store.unmarkTodayAsTaken()
                        } else {
                            store.undoCatchUp()
                        }
                    }
                    ProductAnalyticsTelemetry.live.todayActionUndone()
                    StreakChangeReport.record(store, reason: .undone)
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
                    startTodayAction(requiresShakeConfirm: requiresShakeConfirm)
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
            case .dueActionAwaitingFirstReminder:
                // The line is information; only the chip logs.
                HStack(spacing: 8) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityFloatingButtonLabel(firstReminderLabel)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "bell")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(firstReminderLabel)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)

                    if let log = logBeforeFirstReminder {
                        Spacer(minLength: 0)
                        Button(action: log) {
                            Text(state.localizedPrimaryLabel(locale: locale))
                                .font(.pillie(15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: PillieTheme.ctaHeight - 24)
                                .background(PillieTheme.dark, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityIdentifier("firstReminderTookIt")
                    }
                }
                .padding(.leading, 22)
                .padding(.trailing, 12)
                .takenCapsule()
                .onAppear { ProductAnalyticsTelemetry.live.firstReminderStateShown() }
                .transition(ctaStateTransition)
            }
        }
        .animation(unifiedStateTransition, value: store.isTodayTaken)
        .animation(unifiedStateTransition, value: store.isRefillDue)
        .animation(unifiedStateTransition, value: store.todayDueAction == nil)
        .animation(unifiedStateTransition, value: store.openCatchUp == nil)
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
        store.civilDay.formatted(
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

    private func startTodayAction(requiresShakeConfirm: Bool) {
        ProductAnalyticsTelemetry.live.todayActionStarted()
        if requiresShakeConfirm {
            shakeLog = store.todayLog
            holdsPackCardLog = true
            shakeStreakChange = StreakChange(
                before: store.currentStreak,
                after: store.streakAfterCompletingToday
            )
            showShakeConfirm = true
        } else {
            completeTodayAction()
        }
    }

    /// `shown` is the log the shake cover displayed, which can outlast its live day.
    private func completeTodayAction(shown: PillStore.TodayLog? = nil) {
        guard let shown = shown ?? store.todayLog else { return }
        let feedbackResponse = homeFeedback.commitTodayAction(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        let source: AnalyticsSource = if case .dueActionAwaitingFirstReminder = todayActionState {
            .firstReminder
        } else {
            .home
        }
        let logged = withAnimation(feedbackResponse.motionProfile.animation) {
            store.complete(shown)
        }
        guard logged else { return }
        ProductAnalyticsTelemetry.live.todayActionCompleted(source: source)
        StreakChangeReport.record(store, reason: .logged)
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
        configuration.label.takenCapsule()
    }
}

private extension View {
    func takenCapsule() -> some View {
        font(.pillie(18, weight: .semibold))
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
