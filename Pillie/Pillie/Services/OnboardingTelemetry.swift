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
  static let coreOnboardingCompletedEmittedKey = "core_onboarding_completed_emitted"
  static let trialOfferViewedEmittedKey = "trial_offer_viewed_emitted"
  static let trialActivatedEmittedKey = "trial_activated_emitted"
  static let blockerSetupStartedEmittedKey = "blocker_setup_started_emitted"
  static let blockerSetupSkippedEmittedKey = "blocker_setup_skipped_emitted"
  static let blockerSetupCompletedEmittedKey = "blocker_setup_completed_emitted"

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

    if transition.direction == .forward,
       transition.from == .reminderPlan,
       transition.to == .appBlocking,
       !defaults.bool(forKey: Self.coreOnboardingCompletedEmittedKey) {
      defaults.set(true, forKey: Self.coreOnboardingCompletedEmittedKey)
      telemetry.coreOnboardingCompleted()
    }
  }

  func trialOfferViewed() {
    emitOnce(key: Self.trialOfferViewedEmittedKey) {
      telemetry.trialOfferViewed()
    }
  }

  func trialActivated() {
    emitOnce(key: Self.trialActivatedEmittedKey) {
      telemetry.trialActivated()
    }
  }

  func blockerSetupStarted() {
    emitOnce(key: Self.blockerSetupStartedEmittedKey) {
      telemetry.blockerSetupStarted()
    }
  }

  func blockerSetupSkipped() {
    emitOnce(key: Self.blockerSetupSkippedEmittedKey) {
      telemetry.blockerSetupSkipped()
    }
  }

  func blockerSetupCompleted() {
    emitOnce(key: Self.blockerSetupCompletedEmittedKey) {
      telemetry.blockerSetupCompleted()
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

  private func emitOnce(key: String, event: () -> Void) {
    guard !defaults.bool(forKey: key) else { return }
    defaults.set(true, forKey: key)
    event()
  }
}
