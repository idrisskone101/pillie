//
//  ContentView.swift
//  Pillie
//
//  Created by Idriss Kone on 2026-02-17.
//

import SwiftUI

struct ContentView: View {
  @AppStorage(OnboardingFlow.stepStorageKey) private var onboardingStep = OnboardingFlow.firstStep.rawValue
  @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @Environment(PillStore.self) private var store
  @State private var isLoading = true
  @State private var iconScale: CGFloat = 0.9
  @State private var protectionPlanModel = ProtectionPlanOnboardingModel()
  @State private var showUpdateTrialAnnouncement = false
  @State private var updateTrialWantsBlockerSetup = false
  @State private var showUpdateTrialBlockerSetup = false
  @State private var onboardingCommerceResolution = CommerceResolutionAttempt()
  @State private var isResolvingOnboardingAccess = false
  @State private var onboardingAccessResolutionFailed = false
  @State private var isResolvingRootCommerce = false
  @State private var rootCommerceResolutionFailed = false
  private let onboardingTelemetry = OnboardingTelemetry()
  private let onboardingFeedback = OnboardingInteractionFeedback()
  private let subscriptionManager = SubscriptionManager.shared

  private var currentTrialTermsCohort: TrialTermsCohort {
    subscriptionManager.trialTermsCohort
      ?? TrialInstallCohort.storedAssignment()
      ?? HardPaywallPolicy.cohort(forTrialGrantedAt: Date())
  }

  private var onboardingTrialEndTerms: TrialEndAccessTerms {
    HardPaywallPolicy.terms(
      for: currentTrialTermsCohort,
      hardPaywallEnabled: subscriptionManager.hardPaywallEnabled
    )
  }

  private var rootTrialEndPaywallCohort: TrialEndPaywallCohort {
    AppBlockingManager.shared.hasAppsSelected ? .blockerConfigured : .reminderOnly
  }

  private var rootCommerceGate: RootCommerceGate {
    let now = Date()
    let termsCohort = subscriptionManager.trialTermsCohort
      ?? TrialInstallCohort.storedAssignment()
      ?? HardPaywallPolicy.cohort(
        forTrialGrantedAt: subscriptionManager.trialGrantDate ?? now
      )
    return RootCommerceGate.resolve(
      state: PlusAccessState(
        hasEntitlement: subscriptionManager.hasEntitlement,
        trialGrantDate: subscriptionManager.trialGrantDate
      ),
      termsCohort: termsCohort,
      hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
      entitlementResolved: subscriptionManager.hasResolvedEntitlement,
      configurationResolved: subscriptionManager.hasResolvedHardPaywallConfiguration,
      calendar: .current,
      now: now
    )
  }

  private var onboardingTrialActivationRoute: OnboardingTrialActivationRoute {
    OnboardingTrialActivationRoute.resolve(
      hasEntitlement: subscriptionManager.hasEntitlement,
      entitlementResolved: subscriptionManager.hasResolvedEntitlement,
      configurationResolved: subscriptionManager.hasResolvedHardPaywallConfiguration
    )
  }

  var body: some View {
    ZStack {
      // Main content
      ZStack {
        if onboardingStep < OnboardingFlow.Step.productDemo.rawValue {
          // New Protection Plan Onboarding intro (Welcome -> Analytics Consent).
          ProtectionPlanOnboardingShell(
            model: protectionPlanModel,
            splashActive: isLoading,
            onIntroFinished: handoffFromProtectionPlanIntro
          )
          .transition(.opacity)
        } else {
	        switch OnboardingFlow.visibleStep(
            for: onboardingStep,
            isPlus: subscriptionManager.hasPlusAccess,
            selectedFreePlan: onboardingSelectedFreePlan
          ) {
	        case .welcome:
	          WelcomeView {
              continueDemoMoment(to: .productDemo)
	          }
          .transition(
            .asymmetric(
              insertion: .move(edge: .leading),
              removal: .move(edge: .leading)
            ))

	        case .analyticsConsent:
	          // Retired: the Analytics Consent screen was removed (analytics is
	          // collected for everyone). The new shell owns steps 0–1, so this
	          // legacy arm is unreachable and only exists to keep the switch exhaustive.
	          Color.clear

	        case .productDemo:
	          ProductDemoMomentView(
	            onContinue: {
                continueDemoMoment(to: .plusBlockingDemo)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .plusBlockingDemo:
	          PlusBlockingDemoView(
	            onContinue: {
                continueDemoMoment(to: .analyticsConsent)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .reviewPrompt:
	          // Retired step: `visibleStep` migrates it forward to `.painPoints`, so
	          // this arm only exists to keep the switch exhaustive and is never shown.
	          Color.clear

	        case .painPoints:
	          ProtectionPlanDistractionChoicesView(
	            model: protectionPlanModel,
	            progress: ProtectionPlanProgressIndex.progress(for: .painPoints),
	            onBack: {
                backFromQuestionsToProof()
	            },
	            onContinue: {
	              // Distraction Choices are committed inside ProtectionPlanDistractionChoicesView.
                continueSetupStep(to: .missFrequency)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .goal:
	          // Retired standalone outcome step: `visibleStep` migrates it forward.
	          Color.clear

	        case .missFrequency:
	          ProtectionPlanFailureFrequencyView(
	            model: protectionPlanModel,
	            progress: ProtectionPlanProgressIndex.progress(for: .missFrequency),
	            initialSelection: store.missFrequency,
	            onBack: {
                lowRiskTransition(to: .painPoints)
	            },
	            onContinue: { freq in
	              store.missFrequency = freq
                continueSetupStep(to: .acquisitionSource)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .riskWindow:
	          // Retired standalone risk-window step: `visibleStep` migrates it forward.
	          Color.clear

        case .draftBlockedApps:
          // Retired step: `visibleStep` migrates it forward to `.acquisitionSource`,
          // so this arm only exists to keep the switch exhaustive and is never shown.
          Color.clear

        case .acquisitionSource:
	          ProtectionPlanAcquisitionSourceView(
	            progress: ProtectionPlanProgressIndex.progress(for: .acquisitionSource),
	            initialSelection: store.acquisitionSource,
	            onBack: {
                lowRiskTransition(to: .missFrequency)
	            },
            onContinue: { source in
              store.acquisitionSource = source
	              ProductAnalyticsTelemetry.live.onboardingAcquisitionSourceCompleted(source)
              // If RevenueCat already configured this session (e.g. offerings were
              // prefetched), forward the source now so the subscriber attribute
              // exists before any same-session purchase (#197); otherwise the
              // configure-time attribution pass picks it up from PillStore.
              SubscriptionManager.shared.recordAcquisitionSource(source)
                continueSetupStep(to: .method)
	            },
	            onSkip: {
                lowRiskTransition(to: .method)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .method:
	          ProtectionPlanRoutineMethodView(
	            progress: ProtectionPlanProgressIndex.progress(for: .method),
	            initialMethod: store.contraceptiveMethod,
	            onBack: {
                lowRiskTransition(to: .acquisitionSource)
	            },
	            onContinue: { method in
	              store.contraceptiveMethod = method
                continueSetupStep(to: .schedule)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .schedule:
	          ProtectionPlanRoutineDetailsView(
	            progress: ProtectionPlanProgressIndex.progress(for: .schedule),
	            onBack: {
                lowRiskTransition(to: .method)
	            },
            onContinue: { regimen, customActive, customBreak, cycleDay in
              store.startNewProtocol(
                method: store.contraceptiveMethod,
                regimen: regimen,
                customActiveDays: customActive,
                customBreakDays: customBreak,
                cycleDay: cycleDay,
                preserveHistory: false
              )
              if store.appActivatedDate == nil {
                store.appActivatedDate = store.today
	              }
              continueSetupStep(to: .reminderTime)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .reminderTime:
	          ProtectionPlanReminderTimeView(
	            progress: ProtectionPlanProgressIndex.progress(for: .reminderTime),
	            onBack: {
                lowRiskTransition(to: .schedule)
	            },
	            onContinue: {
                // Arriving at the plan from the flow rebuilds it, so play the reveal
                // animation. (Returning from the paywall keeps the flag set and skips it.)
                protectionPlanModel.hasRevealedDiagnosisPlan = false
                continueSetupStep(to: .reminderPlan)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .reminderPlan:
	          ProtectionPlanDiagnosisView(
	            model: protectionPlanModel,
	            onBack: {
                lowRiskTransition(to: .reminderTime)
	            },
	            onContinue: {
                // Mark the reveal as played so returning here from app-blocking setup
                // shows the finished plan instead of replaying the loading animation.
                protectionPlanModel.hasRevealedDiagnosisPlan = true
                if let nextStep = OnboardingFlow.nextStep(after: .reminderPlan) {
                  continueSetupStep(to: nextStep)
                }
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .mechanismProof:
	          ProtectionPlanMechanismProofView(
	            model: protectionPlanModel,
	            onBack: {
                lowRiskTransition(to: .reminderPlan)
	            },
	            onContinue: {
                continueSetupStep(to: .trialGranted)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .paywall, .freePlanConfirmation:
	          // Retired (issue #164 / ADR 0007): the onboarding paywall and the
	          // free-plan confirmation behind it were replaced by the Trial Granted
	          // Moment. `visibleStep` migrates both forward to `.trialGranted`, so
	          // these arms are unreachable and only keep the switch exhaustive.
	          Color.clear

	        case .trialGranted:
	          TrialGrantedMomentView(
	            onBack: {
                lowRiskTransition(to: .reminderPlan)
	            },
	            onContinue: {
                continueSetupStep(to: .appBlocking)
	            }
	          )
	          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .appBlocking:
	          appBlockingStep
	          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .protectionPlanReady:
	          ProtectionPlanReadyView(
	            onContinue: {
                // Hands off into the app. Core onboarding was already counted at the
                // reminder plan; this terminal boundary classifies genuine protection.
                routeOnboardingCompletion(
                  response: onboardingFeedback.continueSetupStep(
                    accessibilityReduceMotion: accessibilityReduceMotion
                  )
                )
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .opacity
            ))

	        case .complete, nil:
	          if rootCommerceGate == .verifyingAccess {
	            CommerceAccessVerificationView(
	              isWorking: isResolvingRootCommerce,
	              didFail: rootCommerceResolutionFailed,
	              onRetry: refreshRootCommerceAccess,
	              onRestore: restoreRootCommerceAccess
	            )
	            .transition(.opacity)
	            .task {
	              await resolveRootCommerceAccess()
	            }
	          } else {
	            MainTabView()
	            .transition(.opacity)
	            .onAppear {
	              evaluateExistingUserTrialGrant()
	            }
	            .onChange(of: subscriptionManager.hasResolvedEntitlement) { _, _ in
	              // Entitlement usually resolves after the first render — re-run
	              // the check once RevenueCat state is actually known.
	              evaluateExistingUserTrialGrant()
	            }
	            .sheet(
	              isPresented: $showUpdateTrialAnnouncement,
	              onDismiss: {
	                // Chain into the Settings blocker editor only after the
	                // announcement has fully dismissed — presenting a second sheet
	                // while the first is still up is dropped by SwiftUI.
	                if updateTrialWantsBlockerSetup {
	                  updateTrialWantsBlockerSetup = false
	                  showUpdateTrialBlockerSetup = true
	                }
	              }
	            ) {
	              UpdateTrialAnnouncementView(
	                onSetUpBlocking: {
	                  updateTrialWantsBlockerSetup = true
	                  showUpdateTrialAnnouncement = false
	                },
	                onDismiss: {
	                  showUpdateTrialAnnouncement = false
	                }
	              )
	              .presentationDetents([.height(UpdateTrialAnnouncementView.presentationHeight)])
	              .presentationDragIndicator(.hidden)
	              .presentationBackground(PillieTheme.bg)
	            }
	            .sheet(isPresented: $showUpdateTrialBlockerSetup) {
	              // The existing Settings blocker editor: completing setup here
	              // runs under the freshly granted trial's Plus Access, so a valid
	              // save activates blocking exactly like any Plus user's.
	              BlockedAppsEditor()
	                .presentationDetents([.height(430)])
	                .presentationDragIndicator(.hidden)
	                .presentationBackground(PillieTheme.bg)
	            }
	          }
	        }
        }
      }
      .font(.pillieBody())

      // Splash screen overlay
      if isLoading {
        ZStack {
          PillieTheme.coral
            .ignoresSafeArea()

          Image("SplashIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
              Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 20, y: 8)
            .scaleEffect(iconScale)
        }
        .transition(.opacity)
        .zIndex(1)
        .allowsHitTesting(false)
      }
    }
    #if DEBUG
    .overlay(alignment: .bottomTrailing) {
      if !isLoading, OnboardingFlow.isOnboardingActive(rawStep: onboardingStep) {
        DeveloperMenuEntryButton()
          .padding(.trailing, 16)
          .padding(.bottom, 28)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .pillieDebugQADidApply)) { _ in
      evaluateExistingUserTrialGrant()
    }
    #endif
    .task {
      withAnimation(.easeOut(duration: 0.5)) {
        iconScale = 1.0
      }
      try? await Task.sleep(for: .seconds(1.5))
      withAnimation(.easeInOut(duration: 0.4)) {
        isLoading = false
      }
      // Entitlement may have resolved while the splash was still covering the
      // app; the announcement check waits for the splash, so re-run it now.
      evaluateExistingUserTrialGrant()
    }
    .onAppear {
      normalizeVisibleOnboardingStep()
      trackOnboardingStepViewed(onboardingStep)
    }
    .onChange(of: onboardingStep) { _, newStep in
      trackOnboardingStepViewed(newStep)
    }
    .onChange(of: subscriptionManager.hasPlusAccess) { _, _ in
      normalizeVisibleOnboardingStep()
    }
  }

  /// Issue #165 (ADR 0007): grant the Reverse Trial to the existing base on
  /// first launch after the introducing update. Runs whenever the onboarded
  /// main UI is (re)entered, when entitlement state resolves, and when the
  /// splash clears; `ExistingUserTrialGrant` decides, this method executes —
  /// grant, `trial_granted` (source: update), the one-shot persisted window,
  /// and the announcement sheet.
  private func evaluateExistingUserTrialGrant() {
    // Never present the announcement while the splash still covers the app —
    // undecided states leave the window open, so the check re-runs after it.
    guard !isLoading else { return }

    let defaults = UserDefaults.standard
    let termsCohort = currentTrialTermsCohort
    let decision = ExistingUserTrialGrant.evaluate(
      for: ExistingUserTrialGrant.State(
        isOnboardingComplete: !OnboardingFlow.isOnboardingActive(rawStep: onboardingStep),
        isEntitlementResolved: subscriptionManager.hasResolvedEntitlement,
        hasEntitlement: subscriptionManager.hasEntitlement,
        hasTrialGrant: subscriptionManager.trialGrantDate != nil,
        termsCohort: termsCohort,
        alreadyHandled: defaults.bool(forKey: ExistingUserTrialGrant.handledStorageKey)
      )
    )

    if ExistingUserTrialGrant.closesWindow(decision) {
      defaults.set(true, forKey: ExistingUserTrialGrant.handledStorageKey)
    }
    guard decision == .grantAndAnnounce else { return }

    // Same once-only contract as the Trial Granted Moment: the event fires iff
    // the grant was actually written.
    if subscriptionManager.grantReverseTrial(termsCohort: termsCohort) {
      ProductAnalyticsTelemetry.live.updateTrialGranted()
    }
    showUpdateTrialAnnouncement = true
  }

  /// Hands off from the new Protection Plan intro into the existing onboarding
  /// flow. Lands at `painPoints` (the first question) so the legacy welcome,
  /// product demos, and legacy analytics-consent step are skipped (consent is never
  /// asked twice) and the retired review request is bypassed entirely.
  private func handoffFromProtectionPlanIntro() {
    guard onboardingStep < OnboardingFlow.Step.painPoints.rawValue else { return }
    withAnimation(.easeInOut(duration: 0.3)) {
      setOnboardingStep(.painPoints)
    }
  }

  private func setOnboardingStep(_ step: OnboardingFlow.Step) {
    let previousStep = onboardingStep
    let nextStep = step.rawValue
    onboardingTelemetry.stepCompleted(from: previousStep, to: nextStep)

    if OnboardingFlow.completedOnboarding(from: previousStep, to: nextStep) {
      // Classify the optional blocker outcome at the terminal handoff. Core
      // onboarding was already counted at reminderPlan -> trialGranted.
      // Reminder-only completion reports
      // `reminder_only_completion`; only genuine activation (saved blocker config +
      // Screen Time authorization) reports `protection_plan_activated`.
      ProductAnalyticsTelemetry.live.onboardingOutcomeClassified(
        ProtectionPlanCompletion.outcome(for: currentCompletionState)
      )
    }

    onboardingStep = nextStep
    UserDefaults.standard.set(nextStep, forKey: OnboardingFlow.stepStorageKey)
  }

  /// The blocker/entitlement state captured at the moment onboarding completes.
  private var currentCompletionState: ProtectionPlanCompletion.State {
    let blocking = AppBlockingManager.shared
    return ProtectionPlanCompletion.State(
      isEntitled: subscriptionManager.hasPlusAccess,
      screenTimeAuthorized: blocking.authorizationStatus == .approved,
      // A non-empty saved selection — independent of the blocking-enabled pause toggle.
      blockerConfigSaved: blocking.hasAppsSelected
    )
  }

  private var blockerAuthorizationAnalyticsState: AnalyticsAuthorizationState {
    switch AppBlockingManager.shared.authorizationStatus {
    case .notDetermined: return .notRequested
    case .denied: return .denied
    case .approved: return .authorized
    }
  }

  private func trackOnboardingStepViewed(_ step: Int) {
    onboardingTelemetry.stepViewed(step)
  }

  private func normalizeVisibleOnboardingStep() {
    if let persistedStep = OnboardingFlow.step(for: onboardingStep) {
      let migratedAnswers = ProtectionPlanPersonalizationMigration.answersForResume(
        at: persistedStep,
        desiredOutcome: protectionPlanModel.delayConsequence,
        riskWindow: protectionPlanModel.riskWindow
      )
      if migratedAnswers.desiredOutcome != protectionPlanModel.delayConsequence {
        protectionPlanModel.recordDelayConsequence(migratedAnswers.desiredOutcome)
      }
      if migratedAnswers.riskWindow != protectionPlanModel.riskWindow {
        protectionPlanModel.recordRiskWindow(migratedAnswers.riskWindow)
      }
    }

    guard let visibleStep = OnboardingFlow.visibleStep(
      for: onboardingStep,
      isPlus: subscriptionManager.hasPlusAccess,
      selectedFreePlan: onboardingSelectedFreePlan
    ),
    visibleStep.rawValue != onboardingStep else { return }

    onboardingStep = visibleStep.rawValue
    UserDefaults.standard.set(visibleStep.rawValue, forKey: OnboardingFlow.stepStorageKey)
  }

  private func continueDemoMoment(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.continueDemoMoment(
        accessibilityReduceMotion: accessibilityReduceMotion))
  }

  @ViewBuilder
  private var appBlockingStep: some View {
    if onboardingTrialActivationRoute == .verifyingAccess {
      CommerceAccessVerificationView(
        isWorking: isResolvingOnboardingAccess,
        didFail: onboardingAccessResolutionFailed,
        onRetry: refreshOnboardingAccess,
        onRestore: restoreOnboardingAccess
      )
      .task {
        await resolveOnboardingAccess()
      }
    } else {
      AppBlockingSetupView(
        trialEndTerms: onboardingTrialEndTerms,
        isPaidSubscriber: onboardingTrialActivationRoute == .subscriber,
        onBack: {
          if let previousStep = OnboardingFlow.previousStep(before: .appBlocking) {
            lowRiskTransition(to: previousStep)
          }
        },
        onContinue: {
          guard !onboardingCommerceResolution.isResolving else { return }
          if ProtectionPlanCompletion.landsOnProtectionPlanReady(for: currentCompletionState) {
            onboardingTelemetry.blockerSetupCompleted()
            continueSetupStep(to: .protectionPlanReady)
          } else {
            onboardingTelemetry.blockerSetupSkipped(
              authorizationState: blockerAuthorizationAnalyticsState
            )
            routeOnboardingCompletion(
              response: onboardingFeedback.openSoftPaywallOrUpgrade(
                accessibilityReduceMotion: accessibilityReduceMotion
              )
            )
          }
        },
        onSkip: {
          guard !onboardingCommerceResolution.isResolving else { return }
          onboardingTelemetry.blockerSetupSkipped(
            authorizationState: blockerAuthorizationAnalyticsState
          )
          routeOnboardingCompletion(
            response: onboardingFeedback.continueFreePath(
              accessibilityReduceMotion: accessibilityReduceMotion
            )
          )
        }
      )
      .onAppear {
        grantOnboardingTrialIfNeeded(for: onboardingTrialActivationRoute)
        onboardingTelemetry.blockerSetupStarted()
      }
      .onChange(of: onboardingTrialActivationRoute) { previous, current in
        guard OnboardingTrialActivationRoute.shouldGrantTrial(
          after: previous,
          current: current
        ) else { return }
        grantOnboardingTrialIfNeeded(for: current)
      }
    }
  }

  private func grantOnboardingTrialIfNeeded(for route: OnboardingTrialActivationRoute) {
    guard route == .grantTrial,
          OnboardingFlow.grantsReverseTrial(on: .appBlocking) else { return }
    let grantDate = Date()
    let termsCohort = TrialInstallCohort.storedAssignment()
      ?? HardPaywallPolicy.cohort(forTrialGrantedAt: grantDate)
    if subscriptionManager.grantReverseTrial(
      now: grantDate,
      termsCohort: termsCohort
    ) {
      onboardingTelemetry.trialActivated()
    }
  }

  private func refreshOnboardingAccess() {
    Task { await resolveOnboardingAccess() }
  }

  private func resolveOnboardingAccess() async {
    guard !isResolvingOnboardingAccess else { return }
    isResolvingOnboardingAccess = true
    onboardingAccessResolutionFailed = false
    await subscriptionManager.refreshCommerceState()
    onboardingAccessResolutionFailed = onboardingTrialActivationRoute == .verifyingAccess
    isResolvingOnboardingAccess = false
  }

  private func restoreOnboardingAccess() {
    guard !isResolvingOnboardingAccess else { return }
    isResolvingOnboardingAccess = true
    onboardingAccessResolutionFailed = false
    ProductAnalyticsTelemetry.live.restoreStarted(isFromOnboarding: true)
    Task {
      do {
        try await subscriptionManager.restore()
        switch RestoreAccessOutcome.resolve(
          hasEntitlement: subscriptionManager.hasEntitlement
        ) {
        case .restored:
          ProductAnalyticsTelemetry.live.restoreCompleted(isFromOnboarding: true)
        case .missingPurchase:
          ProductAnalyticsTelemetry.live.restoreFailed(isFromOnboarding: true)
        }
      } catch {
        ProductAnalyticsTelemetry.live.restoreFailed(isFromOnboarding: true)
        ProductAnalyticsTelemetry.live.trackError(.restore, error: error)
        onboardingAccessResolutionFailed = true
      }
      isResolvingOnboardingAccess = false
    }
  }

  private func onboardingCompletionRoute(now: Date = Date()) -> OnboardingCompletionRoute {
    let termsCohort = subscriptionManager.trialTermsCohort
      ?? TrialInstallCohort.storedAssignment()
      ?? HardPaywallPolicy.cohort(
        forTrialGrantedAt: subscriptionManager.trialGrantDate ?? now
      )
    return OnboardingCompletionRoute.resolve(
      state: PlusAccessState(
        hasEntitlement: subscriptionManager.hasEntitlement,
        trialGrantDate: subscriptionManager.trialGrantDate
      ),
      termsCohort: termsCohort,
      hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
      entitlementResolved: subscriptionManager.hasResolvedEntitlement,
      configurationResolved: subscriptionManager.hasResolvedHardPaywallConfiguration,
      calendar: .current,
      now: now
    )
  }

  private func routeOnboardingCompletion(
    response: OnboardingInteractionFeedback.Response
  ) {
    switch onboardingCompletionRoute() {
    case .complete, .hardPaywall:
      // Home owns the canonical trial-end purchase surface. For a resolved
      // hard cohort, entering Home immediately satisfies its auto-presentation
      // contract; there is no continue-free state between these transitions.
      transition(to: .complete, response: response)
    case .awaitingCommerceResolution:
      guard onboardingCommerceResolution.begin() else { return }
      // Persist onboarding completion, but do not fail open into usable Home.
      // The completed-root branch resolves to CommerceAccessVerificationView,
      // which owns progress, retry, and restore until customer info is known.
      // Moving synchronously also avoids a late refresh forcing completion after
      // the user navigates Back from this screen.
      transition(to: .complete, response: response)
    }
  }

  private func refreshRootCommerceAccess() {
    Task { await resolveRootCommerceAccess() }
  }

  private func resolveRootCommerceAccess() async {
    guard !isResolvingRootCommerce else { return }
    isResolvingRootCommerce = true
    rootCommerceResolutionFailed = false
    await subscriptionManager.refreshCommerceState()
    rootCommerceResolutionFailed = rootCommerceGate == .verifyingAccess
    isResolvingRootCommerce = false
  }

  private func restoreRootCommerceAccess() {
    guard !isResolvingRootCommerce else { return }
    isResolvingRootCommerce = true
    rootCommerceResolutionFailed = false
    let cohort = rootTrialEndPaywallCohort
    let terms = onboardingTrialEndTerms
    let termsCohort = currentTrialTermsCohort
    ProductAnalyticsTelemetry.live.trialEndRestoreStarted(
      cohort: cohort,
      terms: terms,
      termsCohort: termsCohort
    )
    Task {
      do {
        try await subscriptionManager.restore()
        switch RestoreAccessOutcome.resolve(
          hasEntitlement: subscriptionManager.hasEntitlement
        ) {
        case .restored:
          ProductAnalyticsTelemetry.live.trialEndRestoreCompleted(
            cohort: cohort,
            terms: terms,
            termsCohort: termsCohort
          )
        case .missingPurchase:
          ProductAnalyticsTelemetry.live.trialEndRestoreFailed(
            cohort: cohort,
            terms: terms,
            termsCohort: termsCohort
          )
          rootCommerceResolutionFailed = true
        }
      } catch {
        ProductAnalyticsTelemetry.live.trialEndRestoreFailed(
          cohort: cohort,
          terms: terms,
          termsCohort: termsCohort
        )
        ProductAnalyticsTelemetry.live.trackError(.restore, error: error)
        rootCommerceResolutionFailed = true
      }
      isResolvingRootCommerce = false
    }
  }

  /// Back from the first question to the Early Value Proof. This reverses the
  /// intro handoff: the proof lives in the new shell, so we step the shell's
  /// model back to it and drop the legacy step below `productDemo` so the shell
  /// is shown again (rendering the proof, not the handoff sentinel).
  private func backFromQuestionsToProof() {
    protectionPlanModel.goBack() // handoff sentinel -> earlyValueProof
    withAnimation(.easeInOut(duration: 0.3)) {
      setOnboardingStep(.welcome)
    }
  }

  private func continueSetupStep(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.continueSetupStep(
        accessibilityReduceMotion: accessibilityReduceMotion))
  }

  private func lowRiskTransition(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.continueFreePath(
        accessibilityReduceMotion: accessibilityReduceMotion))
  }

  private func transition(
    to step: OnboardingFlow.Step,
    response: OnboardingInteractionFeedback.Response
  ) {
    withAnimation(response.motionProfile.animation) {
      setOnboardingStep(step)
    }
  }

  private func transitionWithoutFeedback(
    to step: OnboardingFlow.Step,
    motion: PillieMotion.Semantic
  ) {
    let profile = PillieMotion.profile(
      for: motion,
      accessibilityReduceMotion: accessibilityReduceMotion
    )
    withAnimation(profile.animation) {
      setOnboardingStep(step)
    }
  }
}

#Preview {
  ContentView()
    .environment(PillStore.previewStore())
    .environment(AppLanguagePreference())
}

private struct CommerceAccessVerificationView: View {
  let isWorking: Bool
  let didFail: Bool
  let onRetry: () -> Void
  let onRestore: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "checkmark.shield.fill")
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(PillieTheme.coral)

      Text(PillieLocalization.string(
        "commerce.access_verification.title",
        table: "Commerce",
        locale: locale
      ))
      .font(.pillieExtraBold(26))
      .foregroundStyle(PillieTheme.textPrimary)
      .multilineTextAlignment(.center)

      Text(PillieLocalization.string(
        didFail
          ? "commerce.access_verification.error"
          : "commerce.access_verification.body",
        table: "Commerce",
        locale: locale
      ))
      .font(.pillieBody())
      .foregroundStyle(PillieTheme.textMuted)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)

      if isWorking {
        ProgressView()
          .tint(PillieTheme.coral)
          .padding(.top, 4)
      } else {
        Button(action: onRetry) {
          Text(PillieLocalization.string(
            "global.action.retry",
            locale: locale
          ))
          .font(.pillie(17, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: PillieTheme.ctaHeight)
          .background(PillieTheme.dark)
          .clipShape(Capsule())
        }
        .accessibilityIdentifier("commerceAccessRetryButton")

        Button {
          onRestore()
        } label: {
          Text(PillieLocalization.string(
            "paywall.action.restore",
            table: "Commerce",
            locale: locale
          ))
          .font(.pillie(15, weight: .semibold))
          .foregroundStyle(PillieTheme.textMuted)
        }
        .accessibilityIdentifier("commerceAccessRestoreButton")
      }

      Spacer()
    }
    .padding(.horizontal, 32)
    .background(PillieTheme.bg.ignoresSafeArea())
    .accessibilityIdentifier("commerceAccessVerification")
  }
}
