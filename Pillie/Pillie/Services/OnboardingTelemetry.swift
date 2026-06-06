//
//  OnboardingTelemetry.swift
//  Pillie
//

import Foundation

struct OnboardingTelemetry {
  private let telemetry: ProductAnalyticsTelemetry

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.isPlus }
  ) {
    self.telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: isPlus)
  }

  func stepViewed(_ step: Int) {
    guard let analyticsStep = OnboardingFlow.analyticsStep(for: step) else { return }
    if step == 0 {
      telemetry.onboardingStarted(step: analyticsStep)
    }
    telemetry.onboardingStepViewed(analyticsStep)
  }

  func stepCompleted(from previousStep: Int, to nextStep: Int) {
    guard let transition = OnboardingFlow.transition(from: previousStep, to: nextStep),
          let analyticsStep = transition.completedAnalyticsStep else { return }

    if transition.direction == .forward {
      telemetry.onboardingStepCompleted(analyticsStep)
    } else {
      telemetry.onboardingBackTapped(analyticsStep)
    }

    if transition.completesOnboarding {
      telemetry.onboardingCompleted()
    }
  }

  func notificationPermissionRequested() {
    telemetry.notificationPermissionRequested()
  }

  func screenTimePermissionRequested() {
    telemetry.screenTimePermissionRequested()
  }

  func screenTimePermissionCompleted(isAuthorized: Bool) {
    telemetry.screenTimePermissionCompleted(isAuthorized: isAuthorized)
  }
}
