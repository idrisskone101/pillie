//
//  OnboardingTelemetry.swift
//  Pillie
//

import Foundation

struct OnboardingTelemetry {
  /// Persisted latch (UserDefaults) so `onboarding_started` fires exactly once per
  /// install — the first time onboarding is entered — regardless of which screen the
  /// user resumes on or how many times the first screen is re-rendered. Replaces the
  /// fragile `step == 0` position check that missed resumed users entirely (#140).
  static let onboardingStartedEmittedKey = "onboarding_started_emitted"

  private let telemetry: ProductAnalyticsTelemetry
  private let defaults: UserDefaults

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.hasEntitlement },
    defaults: UserDefaults = .standard
  ) {
    self.telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: isPlus)
    self.defaults = defaults
  }

  func stepViewed(_ step: Int) {
    guard let analyticsStep = OnboardingFlow.analyticsStep(for: step) else { return }
    if !defaults.bool(forKey: Self.onboardingStartedEmittedKey) {
      defaults.set(true, forKey: Self.onboardingStartedEmittedKey)
      telemetry.onboardingStarted(step: analyticsStep)
    }
    telemetry.onboardingStepViewed(analyticsStep, stepIndex: OnboardingFlow.displayIndex(for: step))
  }

  func stepCompleted(from previousStep: Int, to nextStep: Int) {
    guard let transition = OnboardingFlow.transition(from: previousStep, to: nextStep),
          let analyticsStep = transition.completedAnalyticsStep else { return }

    // The completed/left step's position in the funnel sequence.
    let stepIndex = OnboardingFlow.displayIndex(for: previousStep)
    if transition.direction == .forward {
      telemetry.onboardingStepCompleted(analyticsStep, stepIndex: stepIndex)
    } else {
      telemetry.onboardingBackTapped(analyticsStep, stepIndex: stepIndex)
    }

    if transition.completesOnboarding {
      telemetry.onboardingCompleted()
    }
  }

  func notificationPermissionRequested() {
    telemetry.notificationPermissionRequested()
  }

  func notificationPermissionCompleted(granted: Bool) {
    telemetry.notificationPermissionCompleted(granted: granted)
  }

  func screenTimePermissionRequested() {
    telemetry.screenTimePermissionRequested()
  }

  func screenTimePermissionCompleted(isAuthorized: Bool) {
    telemetry.screenTimePermissionCompleted(isAuthorized: isAuthorized)
  }
}
