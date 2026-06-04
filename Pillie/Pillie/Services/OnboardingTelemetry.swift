//
//  OnboardingTelemetry.swift
//  Pillie
//

import Foundation

struct OnboardingTelemetry {
  private let analytics: AnalyticsTracking
  private let isPlus: () -> Bool

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.isPlus }
  ) {
    self.analytics = analytics
    self.isPlus = isPlus
  }

  func stepViewed(_ step: Int) {
    guard let analyticsStep = AnalyticsStep(onboardingStep: step) else { return }
    if step == 0 {
      track(
        .onboardingStarted,
        source: .onboarding,
        step: analyticsStep,
        isPlus: isPlus()
      )
    }
    track(
      .onboardingStepViewed,
      source: .onboarding,
      step: analyticsStep,
      isPlus: isPlus()
    )
  }

  func stepCompleted(from previousStep: Int, to nextStep: Int) {
    guard let analyticsStep = AnalyticsStep(onboardingStep: previousStep), previousStep != nextStep
    else {
      return
    }

    track(
      nextStep > previousStep ? .onboardingStepCompleted : .onboardingBackTapped,
      source: .onboarding,
      step: analyticsStep,
      isPlus: isPlus()
    )

    if previousStep <= 14, nextStep > 14 {
      track(.onboardingCompleted, source: .onboarding, isPlus: isPlus())
    }
  }

  func notificationPermissionRequested() {
    track(
      .notificationPermissionRequested,
      source: .onboarding,
      step: .reminderTime,
      isPlus: isPlus()
    )
  }

  func screenTimePermissionRequested() {
    track(
      .screenTimePermissionRequested,
      source: .onboarding,
      step: .appBlocking,
      isPlus: isPlus()
    )
  }

  func screenTimePermissionCompleted(isAuthorized: Bool) {
    track(
      .screenTimePermissionCompleted,
      source: .onboarding,
      step: .appBlocking,
      result: isAuthorized ? .granted : .denied,
      isPlus: isPlus()
    )
  }

  private func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    screen: AnalyticsScreen? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    setting: AnalyticsSetting? = nil,
    acquisitionSource: AcquisitionSource? = nil,
    isPlus: Bool? = nil,
    hasBlockingSelection: Bool? = nil
  ) {
    analytics.track(
      event,
      source: source,
      step: step,
      screen: screen,
      plan: plan,
      result: result,
      setting: setting,
      acquisitionSource: acquisitionSource,
      isPlus: isPlus,
      hasBlockingSelection: hasBlockingSelection
    )
  }
}
