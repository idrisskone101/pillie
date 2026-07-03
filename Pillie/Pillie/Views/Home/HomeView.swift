// xcode: set sdk=iOS

//
//  HomeView.swift
//  Pillie
//

import SwiftUI
import StoreKit

struct HomeView: View {
    @Environment(PillStore.self) var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showRefillConfirmation = false
    @State private var showShakeConfirm = false
    @State private var showBlockingSetup = false
    @State private var showBlockingPaywall = false
    @State private var showTrialStatusSheet = false
    @State private var showTrialKeepPlusPaywall = false
    @State private var adaptiveReminderShownLogged = false
    @State private var reviewPromptShownLogged = false
    @AppStorage("homeBlockingStatusCardDismissed") private var blockingCardDismissed = false
    private let homeFeedback = HomeActionInteractionFeedback()

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
            showBlockingPaywall = true
        }
    }

    /// Copy for the enable-blocking-later card, or `nil` when blocking is active or the
    /// card was dismissed — in which case it does not occupy this Home pass.
    private var blockingCardContent: BlockingStatusCardContent? {
        guard !blockingCardDismissed else { return nil }
        return BlockingStatusCardContent.make(for: blockingPresentation)
    }

    /// Copy + gating for the Adaptive Reminder Time Suggestion card (#126). `nil` for
    /// free users, or when the analyzer has no confident, non-cooled-down suggestion.
    private var adaptiveReminderContent: AdaptiveReminderSuggestionCardContent? {
        AdaptiveReminderSuggestionCardContent.make(
            suggestion: store.adaptiveReminderSuggestion,
            isPlus: SubscriptionManager.shared.hasPlusAccess
        )
    }

    /// Whether a higher-priority Home "ask" card (Refill, Adaptive Reminder, or Blocking)
    /// would render this pass. Feeds the Review Prompt's `higherPriorityCardShowing` input
    /// so the lowest-priority rating ask yields — at most one ask per Home visit (#132).
    private var higherPriorityCardShowing: Bool {
        blockingCardContent != nil || store.isRefillDue || adaptiveReminderContent != nil
    }

    /// Copy + gating for the Home Review Prompt's Sentiment Gate card (#132). `nil` unless
    /// the user has reached Review Prompt Eligibility — an unbroken Streak past the
    /// method-aware threshold, never answered, not in cooldown or capped — and no
    /// higher-priority card is showing. Eligibility math lives entirely in
    /// `ReviewPromptEligibility` (on-device). Shown to free and Plus users alike.
    private var reviewPromptContent: ReviewPromptCardContent? {
        ReviewPromptCardContent.make(
            decision: store.reviewPromptDecision(higherPriorityCardShowing: higherPriorityCardShowing)
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
            calendar: Calendar.current,
            now: Date()
        )
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
                        title: "Today",
                        titleFont: .pillieHeadline().weight(.bold),
                        showsAccessorySlot: true,
                        accessory: {
                            AnyView(
                                HStack {
                                    Text(dateString)
                                        .font(.pillieDate())
                                        .foregroundStyle(PillieTheme.textMuted)

                                    Spacer()

                                    HomeAvatarLogoBadge()
                                }
                            )
                        }
                    )
                        .modifier(FadeInUp(appeared: appeared, delay: 0))

                    if let trial = trialPresentation {
                        TrialIndicatorBadge(
                            label: trial.indicatorLabel,
                            onTap: { showTrialStatusSheet = true }
                        )
                        .modifier(FadeInUp(appeared: appeared, delay: 0.05))
                        .transition(ctaStateTransition)
                    }

                    StatusCard()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.1))

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

                    if let adaptiveContent = adaptiveReminderContent {
                        AdaptiveReminderSuggestionCard(
                            content: adaptiveContent,
                            onAccept: {
                                withAnimation(unifiedStateTransition) {
                                    ScheduleCriticalSettingChange.acceptAdaptiveReminderSuggestion(
                                        store: store,
                                        hour: adaptiveContent.suggestedHour,
                                        minute: adaptiveContent.suggestedMinute
                                    )
                                }
                            },
                            onDismiss: {
                                withAnimation(unifiedStateTransition) {
                                    store.dismissAdaptiveReminderSuggestion(delta: adaptiveContent.deltaMinutes)
                                }
                                ProductAnalyticsTelemetry.live.adaptiveReminderSuggestionDismissed()
                            }
                        )
                        .onAppear {
                            guard !adaptiveReminderShownLogged else { return }
                            adaptiveReminderShownLogged = true
                            ProductAnalyticsTelemetry.live.adaptiveReminderSuggestionShown()
                        }
                        .modifier(FadeInUp(appeared: appeared, delay: 0.15))
                        .transition(ctaStateTransition)
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
                    Text("Keep it up, you're doing great!")
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
                .padding(.bottom, PillieTheme.scrollBottomPaddingWithCTA)
            }

            // Floating button
            floatingButton
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .alert(store.refillBannerTitle, isPresented: $showRefillConfirmation) {
            Button(store.refillCTALabel) {
                startNewPackOrCycle()
                ProductAnalyticsTelemetry.live.newPackOrCycleStarted()
            }
            Button("Not Yet", role: .cancel) {}
        } message: {
            Text("This will start a new \(store.pack.method == .pill ? "pack" : "cycle") from today. Your previous history will be preserved.")
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
                onBack: { showBlockingPaywall = false },
                onContinue: { showBlockingPaywall = false },
                onSkip: { showBlockingPaywall = false }
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
                .presentationDetents([.height(TrialStatusSheet.presentationHeight)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
            }
        }
        .fullScreenCover(isPresented: $showTrialKeepPlusPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
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
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                        Text(store.refillCTALabel)
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
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Completed (Tap to undo)")
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .transition(ctaStateTransition)
            case .noActionDue:
                Button {
                    // No due action for today.
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                        Text("No Action Due Today")
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .allowsHitTesting(false)
                .transition(ctaStateTransition)
            case .dueAction(let action, let requiresShakeConfirm):
                Button {
                    ProductAnalyticsTelemetry.live.todayActionStarted()
                    if requiresShakeConfirm {
                        showShakeConfirm = true
                    } else {
                        completeTodayAction()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                        Text(action.ctaLabel)
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

    // MARK: - Helpers

    private var dateString: String {
        PillieDateFormatters.homeHeader.string(from: Date())
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
        if let mailURL = FeedbackEscapeHatch.mailURL {
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
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.sage)
            .clipShape(Capsule())
    }
}

#Preview {
    HomeView()
        .environment(PillStore.previewStore())
}
