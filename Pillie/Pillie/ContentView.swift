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
  private let onboardingTelemetry = OnboardingTelemetry()
  private let onboardingFeedback = OnboardingInteractionFeedback()

  var body: some View {
    ZStack {
      // Main content
      ZStack {
	        switch OnboardingFlow.step(for: onboardingStep) {
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
                continueDemoMoment(to: .reviewPrompt)
	            },
	            onDecline: {
	              AnalyticsManager.shared.setAnalyticsEnabled(false)
                continueDemoMoment(to: .reviewPrompt)
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
	          ReviewPromptView(
	            onContinue: {
                reviewPromptTransition(to: .painPoints)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .painPoints:
	          PainPointPickerView(
	            onBack: {
                lowRiskTransition(to: .reviewPrompt)
	            },
	            onContinue: { points in
	              store.painPoints = points
                continueSetupStep(to: .goal)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .goal:
	          GoalPickerView(
	            onBack: {
                lowRiskTransition(to: .painPoints)
	            },
	            onContinue: { goal in
	              store.personalGoal = goal
                continueSetupStep(to: .missFrequency)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .missFrequency:
	          MissFrequencyView(
	            onBack: {
                lowRiskTransition(to: .goal)
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

	        case .acquisitionSource:
	          AcquisitionSourceView(
	            onBack: {
                lowRiskTransition(to: .missFrequency)
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
	          MethodPickerView(
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
	          MethodDetailsView(
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
	          TimeSetupView(
	            onBack: {
                lowRiskTransition(to: .schedule)
	            },
	            onContinue: {
                continueSetupStep(to: .reminderPlan)
	            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

	        case .reminderPlan:
	          ReminderPlanView(
	            onBack: {
                lowRiskTransition(to: .reminderTime)
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
                    isPlus: SubscriptionManager.shared.isPlus,
                    selectedFreePlan: onboardingSelectedFreePlan
                  ),
                  motion: .commitSpring
                )
            },
            onSkip: {
	              onboardingSelectedFreePlan = true
                transitionWithoutFeedback(
                  to: OnboardingFlow.nextStepAfterPaywall(
                    isPlus: SubscriptionManager.shared.isPlus,
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
                openSoftPaywallOrUpgrade(to: .complete)
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

	        case .complete, nil:
	          MainTabView()
	            .transition(.opacity)
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
      trackOnboardingStepViewed(onboardingStep)
    }
    .onChange(of: onboardingStep) { _, newStep in
      trackOnboardingStepViewed(newStep)
    }
  }

  private func setOnboardingStep(_ step: OnboardingFlow.Step) {
    let previousStep = onboardingStep
    let nextStep = step.rawValue
    onboardingTelemetry.stepCompleted(from: previousStep, to: nextStep)

    onboardingStep = nextStep
    UserDefaults.standard.set(nextStep, forKey: OnboardingFlow.stepStorageKey)
  }

  private func trackOnboardingStepViewed(_ step: Int) {
    onboardingTelemetry.stepViewed(step)
  }

  private func continueDemoMoment(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.continueDemoMoment(
        accessibilityReduceMotion: accessibilityReduceMotion))
  }

  private func reviewPromptTransition(to step: OnboardingFlow.Step) {
    transition(
      to: step,
      response: onboardingFeedback.requestOrSkipReview(
        accessibilityReduceMotion: accessibilityReduceMotion))
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
