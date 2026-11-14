import Foundation

@testable import Pillie

final class DemoFunnelRecorder: AnalyticsTracking {
  struct Event: Equatable {
    let event: AnalyticsEvent
    let source: AnalyticsSource?
    let step: AnalyticsStep?
    let stepIndex: Int?
    let result: AnalyticsResult?
    let shakeCount: Int?
  }

  // Hosted XCTest on the Xcode 27 beta aborts when a class deallocates while a
  // test invocation is on the stack. Retaining every recorder for the process
  // lifetime defers deallocation past the invocation.
  private static var keepAlive: [DemoFunnelRecorder] = []

  init() {
    Self.keepAlive.append(self)
  }

  private(set) var events: [Event] = []

  func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource?,
    step: AnalyticsStep?,
    stepIndex: Int?,
    screen: AnalyticsScreen?,
    plan: AnalyticsPlan?,
    result: AnalyticsResult?,
    setting: AnalyticsSetting?,
    acquisitionSource: AcquisitionSource?,
    isPlus: Bool?,
    hasBlockingSelection: Bool?,
    interventionCount: Int?,
    shakeCount: Int?,
    trialWarningDay: Int?,
    trialEndCohort: TrialEndPaywallCohort?,
    titleCustomized: Bool?,
    bodyCustomized: Bool?,
    retryTitleCustomized: Bool?,
    retryBodyCustomized: Bool?,
  ) {
    events.append(
      Event(
        event: event, source: source, step: step, stepIndex: stepIndex, result: result,
        shakeCount: shakeCount))
  }
}
