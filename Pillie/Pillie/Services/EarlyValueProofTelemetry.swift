//
//  EarlyValueProofTelemetry.swift
//  Pillie
//
//  Funnel instrumentation for the Early Value Proof demo (#175). The three
//  interactive stages — drag-the-dot, shake tutorial, unlocked/continue — are
//  phases of a single screen (`ProtectionPlanEarlyValueProofView`), not
//  `OnboardingFlow` steps, so `onboarding_step_viewed` never fired for them and
//  the funnel's step_index jumped straight from 0 (welcome) to 4 (pain_points).
//  This type owns the stage→step mapping and their 1–3 indices.
//

import Foundation

/// The visible phase of the Early Value Proof screen, in funnel order.
enum EarlyValueProofStage: CaseIterable {
  case drag
  case shake
  case unlocked

  var analyticsStep: AnalyticsStep {
    switch self {
    case .drag: return .demoDrag
    case .shake: return .demoShake
    case .unlocked: return .demoUnlocked
    }
  }

  /// The stage's funnel position: welcome is 0 and pain_points is 4, so the
  /// demo stages fill 1–3.
  var stepIndex: Int {
    switch self {
    case .drag: return 1
    case .shake: return 2
    case .unlocked: return 3
    }
  }
}

struct EarlyValueProofTelemetry {
  private let telemetry: ProductAnalyticsTelemetry
  /// The drag↔shake latch is reversible (hysteresis), so the user can bounce
  /// between stages; each stage reports one view per screen visit.
  private var viewedStages: Set<EarlyValueProofStage> = []

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.hasEntitlement }
  ) {
    self.telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: isPlus)
  }

  mutating func stageViewed(_ stage: EarlyValueProofStage) {
    guard viewedStages.insert(stage).inserted else { return }
    telemetry.onboardingStepViewed(stage.analyticsStep, stepIndex: stage.stepIndex)
  }

  /// The shake check-in resolved. `shakeCount` is the number of real shakes
  /// performed before resolution (0–3); the CTA-tap fallback shows up as a
  /// resolution with a count below 3.
  func shakeCheckInCompleted(shakeCount: Int) {
    telemetry.demoShakeCompleted(shakeCount: shakeCount)
  }
}
