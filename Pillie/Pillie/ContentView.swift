//
//  ContentView.swift
//  Pillie
//
//  Created by Idriss Kone on 2026-02-17.
//

import SwiftUI

struct ContentView: View {
  @AppStorage("onboardingStep") private var onboardingStep = 0
  @AppStorage("onboardingSelectedFreePlan") private var onboardingSelectedFreePlan = false
  @Environment(PillStore.self) private var store
  @State private var isLoading = true
  @State private var iconScale: CGFloat = 0.9
  private let onboardingTelemetry = OnboardingTelemetry()

  var body: some View {
    ZStack {
      // Main content
      ZStack {
        switch onboardingStep {
        case 0:
          WelcomeView {
            withAnimation(.easeInOut(duration: 0.4)) {
              setOnboardingStep(1)
            }
          }
          .transition(
            .asymmetric(
              insertion: .move(edge: .leading),
              removal: .move(edge: .leading)
            ))

        case 1:
          AnalyticsConsentView(
            onAllow: {
              AnalyticsManager.shared.setAnalyticsEnabled(true)
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(2)
              }
            },
            onDecline: {
              AnalyticsManager.shared.setAnalyticsEnabled(false)
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(2)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 2:
          ProductDemoMomentView(
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(3)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 3:
          ReviewPromptView(
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(4)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 4:
          PainPointPickerView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(3)
              }
            },
            onContinue: { points in
              store.painPoints = points
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(5)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 5:
          GoalPickerView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(4)
              }
            },
            onContinue: { goal in
              store.personalGoal = goal
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(6)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 6:
          MissFrequencyView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(5)
              }
            },
            onContinue: { freq in
              store.missFrequency = freq
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(7)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 7:
          AcquisitionSourceView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(6)
              }
            },
            onContinue: { source in
              store.acquisitionSource = source
              AnalyticsManager.shared.track(
                .onboardingStepCompleted,
                source: .onboarding,
                step: .acquisitionSource,
                acquisitionSource: source,
                isPlus: SubscriptionManager.shared.isPlus
              )
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(8)
              }
            },
            onSkip: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(8)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 8:
          MethodPickerView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(7)
              }
            },
            onContinue: { method in
              store.contraceptiveMethod = method
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(9)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 9:
          MethodDetailsView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(8)
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
                setOnboardingStep(10)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 10:
          TimeSetupView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(9)
              }
            },
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(11)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 11:
          FreePlanView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(10)
              }
            },
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(12)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 12:
          PremiumChallengePreviewView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(11)
              }
            },
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(13)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 13:
          PremiumPaywallView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(12)
              }
            },
            onContinue: {
              onboardingSelectedFreePlan = false
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(14)
              }
            },
            onSkip: {
              onboardingSelectedFreePlan = true
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(14)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        case 14:
          AppBlockingSetupView(
            onBack: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(13)
              }
            },
            onContinue: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(15)
              }
            },
            onSkip: {
              withAnimation(.easeInOut(duration: 0.4)) {
                setOnboardingStep(15)
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .trailing)
            ))

        default:
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

  private func setOnboardingStep(_ step: Int) {
    let previousStep = onboardingStep
    onboardingTelemetry.stepCompleted(from: previousStep, to: step)

    onboardingStep = step
    UserDefaults.standard.set(step, forKey: "onboardingStep")
  }

  private func trackOnboardingStepViewed(_ step: Int) {
    onboardingTelemetry.stepViewed(step)
  }
}

#Preview {
  ContentView()
    .environment(PillStore.previewStore())
}
