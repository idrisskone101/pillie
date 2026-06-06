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
  @Environment(PillStore.self) private var store
  @State private var isLoading = true
  @State private var iconScale: CGFloat = 0.9
  private let onboardingTelemetry = OnboardingTelemetry()

  var body: some View {
    ZStack {
      // Main content
      ZStack {
	        switch OnboardingFlow.step(for: onboardingStep) {
	        case .welcome:
	          WelcomeView {
	            withAnimation(.easeInOut(duration: 0.4)) {
	              setOnboardingStep(.analyticsConsent)
	            }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.productDemo)
	              }
	            },
	            onDecline: {
	              AnalyticsManager.shared.setAnalyticsEnabled(false)
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.productDemo)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.plusBlockingDemo)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reviewPrompt)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.painPoints)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reviewPrompt)
	              }
	            },
	            onContinue: { points in
	              store.painPoints = points
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.goal)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.painPoints)
	              }
	            },
	            onContinue: { goal in
	              store.personalGoal = goal
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.missFrequency)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.goal)
	              }
	            },
	            onContinue: { freq in
	              store.missFrequency = freq
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.acquisitionSource)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.missFrequency)
	              }
	            },
            onContinue: { source in
              store.acquisitionSource = source
	              ProductAnalyticsTelemetry.live.onboardingAcquisitionSourceCompleted(source)
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.method)
	              }
	            },
	            onSkip: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.method)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.acquisitionSource)
	              }
	            },
	            onContinue: { method in
	              store.contraceptiveMethod = method
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.schedule)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.method)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reminderTime)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.schedule)
	              }
	            },
	            onContinue: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reminderPlan)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reminderTime)
	              }
	            },
	            onContinue: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.paywall)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.reminderPlan)
	              }
	            },
	            onContinue: {
	              onboardingSelectedFreePlan = false
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(
	                  OnboardingFlow.nextStepAfterPaywall(
	                    isPlus: SubscriptionManager.shared.isPlus,
	                    selectedFreePlan: onboardingSelectedFreePlan
	                  ))
              }
            },
            onSkip: {
	              onboardingSelectedFreePlan = true
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(
	                  OnboardingFlow.nextStepAfterPaywall(
	                    isPlus: SubscriptionManager.shared.isPlus,
	                    selectedFreePlan: onboardingSelectedFreePlan
	                  ))
              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.paywall)
	              }
	            },
	            onContinue: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.complete)
	              }
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
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.paywall)
	              }
	            },
	            onContinue: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.complete)
	              }
	            },
	            onSkip: {
	              withAnimation(.easeInOut(duration: 0.4)) {
	                setOnboardingStep(.complete)
	              }
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
}

#Preview {
  ContentView()
    .environment(PillStore.previewStore())
}
