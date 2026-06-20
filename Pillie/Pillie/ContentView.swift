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
  private let onboardingTelemetry = OnboardingTelemetry()
  private let onboardingFeedback = OnboardingInteractionFeedback()
  private let subscriptionManager = SubscriptionManager.shared

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
            isPlus: subscriptionManager.isPlus,
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
	          AnalyticsConsentView(
	            onAllow: {
	              AnalyticsManager.shared.setAnalyticsEnabled(true)
                continueDemoMoment(to: .painPoints)
	            },
	            onDecline: {
	              AnalyticsManager.shared.setAnalyticsEnabled(false)
                continueDemoMoment(to: .painPoints)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

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
                continueSetupStep(to: .goal)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .goal:
	          ProtectionPlanDelayConsequenceView(
	            model: protectionPlanModel,
	            progress: ProtectionPlanProgressIndex.progress(for: .goal),
	            onBack: {
                lowRiskTransition(to: .painPoints)
	            },
	            onContinue: {
	              // Delay Consequence is committed inside ProtectionPlanDelayConsequenceView.
                continueSetupStep(to: .missFrequency)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .missFrequency:
	          ProtectionPlanFailureFrequencyView(
	            progress: ProtectionPlanProgressIndex.progress(for: .missFrequency),
	            initialSelection: store.missFrequency,
	            onBack: {
                lowRiskTransition(to: .goal)
	            },
	            onContinue: { freq in
	              store.missFrequency = freq
                continueSetupStep(to: .riskWindow)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .riskWindow:
          ProtectionPlanRiskWindowView(
            model: protectionPlanModel,
            progress: ProtectionPlanProgressIndex.progress(for: .riskWindow),
            onBack: {
              lowRiskTransition(to: .missFrequency)
            },
            onContinue: {
              // Risk Window is committed inside ProtectionPlanRiskWindowView.
              continueSetupStep(to: .draftBlockedApps)
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case .draftBlockedApps:
          ProtectionPlanDraftBlockedAppsView(
            model: protectionPlanModel,
            progress: ProtectionPlanProgressIndex.progress(for: .draftBlockedApps),
            onBack: {
              lowRiskTransition(to: .riskWindow)
            },
            onContinue: {
              // Draft Blocked App Choices are committed inside the view.
              continueSetupStep(to: .acquisitionSource)
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case .acquisitionSource:
	          ProtectionPlanAcquisitionSourceView(
	            progress: ProtectionPlanProgressIndex.progress(for: .acquisitionSource),
	            initialSelection: store.acquisitionSource,
	            onBack: {
                lowRiskTransition(to: .draftBlockedApps)
	            },
            onContinue: { source in
              store.acquisitionSource = source
	              ProductAnalyticsTelemetry.live.onboardingAcquisitionSourceCompleted(source)
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
                // Mark the reveal as played so returning here (Back from the paywall)
                // shows the finished plan instead of replaying the loading animation.
                protectionPlanModel.hasRevealedDiagnosisPlan = true
                continueSetupStep(to: .paywall)
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
                continueSetupStep(to: .paywall)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .paywall:
	          PremiumPaywallView(
	            onBack: {
                lowRiskTransition(to: .reminderPlan)
	            },
	            onContinue: {
	              onboardingSelectedFreePlan = false
                transitionWithoutFeedback(
                  to: OnboardingFlow.nextStepAfterPaywall(
                    isPlus: subscriptionManager.isPlus,
                    selectedFreePlan: onboardingSelectedFreePlan
                  ),
                  motion: .commitSpring
                )
            },
	            onSkip: {
	              onboardingSelectedFreePlan = true
                transitionWithoutFeedback(
                  to: OnboardingFlow.nextStepAfterPaywall(
                    isPlus: subscriptionManager.isPlus,
                    selectedFreePlan: onboardingSelectedFreePlan
                  ),
                  motion: .standard
                )
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .freePlanConfirmation:
	          FreePlanConfirmationView(
	            onBack: {
                lowRiskTransition(to: .paywall)
	            },
	            onContinue: {
                continueFreePath(to: .complete)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .appBlocking:
	          AppBlockingSetupView(
	            onBack: {
                lowRiskTransition(to: .paywall)
	            },
	            onContinue: {
                // A valid save with Screen Time authorization is genuine activation —
                // land on the Pill Protection Plan Ready screen. Anything short of
                // activation (e.g. authorized but later cleared) opens the app directly.
                if ProtectionPlanCompletion.landsOnProtectionPlanReady(for: currentCompletionState) {
                  continueSetupStep(to: .protectionPlanReady)
                } else {
                  openSoftPaywallOrUpgrade(to: .complete)
                }
	            },
	            onSkip: {
                continueFreePath(to: .complete)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .protectionPlanReady:
	          ProtectionPlanReadyView(
	            onContinue: {
                // Hands off into the app. Leaving the ready screen for `.complete` is
                // the completion boundary that fires `onboarding_completed` and the
                // `protection_plan_activated` classification.
                continueSetupStep(to: .complete)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .opacity
            ))

	        case .complete, nil:
	          MainTabView()
	            .transition(.opacity)
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
    .task {
      withAnimation(.easeOut(duration: 0.5)) {
        iconScale = 1.0
      }
      try? await Task.sleep(for: .seconds(1.5))
      withAnimation(.easeInOut(duration: 0.4)) {
        isLoading = false
      }
    }
    .onAppear {
      normalizeVisibleOnboardingStep()
      trackOnboardingStepViewed(onboardingStep)
    }
    .onChange(of: onboardingStep) { _, newStep in
      trackOnboardingStepViewed(newStep)
    }
    .onChange(of: subscriptionManager.isPlus) { _, _ in
      normalizeVisibleOnboardingStep()
    }
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
      // Classify the terminal completion state. Reminder-only completion reports
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
      isEntitled: subscriptionManager.isPlus,
      screenTimeAuthorized: blocking.authorizationStatus == .approved,
      // A non-empty saved selection — independent of the blocking-enabled pause toggle.
      blockerConfigSaved: blocking.hasAppsSelected
    )
  }

  private func trackOnboardingStepViewed(_ step: Int) {
    onboardingTelemetry.stepViewed(step)
  }

  private func normalizeVisibleOnboardingStep() {
    guard let visibleStep = OnboardingFlow.visibleStep(
      for: onboardingStep,
      isPlus: subscriptionManager.isPlus,
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

  private func openSoftPaywallOrUpgrade(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.openSoftPaywallOrUpgrade(
        accessibilityReduceMotion: accessibilityReduceMotion))
  }

  private func continueFreePath(to step: OnboardingFlow.Step) {
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
}
