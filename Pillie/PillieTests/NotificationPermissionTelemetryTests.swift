//
//  NotificationPermissionTelemetryTests.swift
//  PillieTests
//
//  Covers the notification permission outcome event (#175):
//  `notification_permission_requested` existed with no granted/denied outcome,
//  unlike the symmetric Screen Time pair, so the funnel could not tell whether
//  the schedule/reminder_time drop correlated with denied notifications.
//
//  Deliberately a plain (non-`@MainActor`) XCTestCase exercising value-type
//  telemetry, to avoid the Xcode 27 hosted-XCTest @MainActor deinit crash.
//

import XCTest

@testable import Pillie

final class NotificationPermissionTelemetryTests: XCTestCase {

  func testGrantedOutcomeFiresCompletedWithGrantedResult() {
    let recorder = DemoFunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    telemetry.notificationPermissionCompleted(granted: true)

    let completed = recorder.events.first { $0.event == .notificationPermissionCompleted }
    XCTAssertEqual(completed?.result, .granted)
    XCTAssertEqual(completed?.source, .onboarding)
    // Symmetric with the requested event: same step, so the pair lines up in
    // the funnel exactly like the screen_time pair does on app_blocking.
    XCTAssertEqual(completed?.step, .reminderTime)
  }

  func testDeniedOutcomeFiresCompletedWithDeniedResult() {
    let recorder = DemoFunnelRecorder()
    let telemetry = OnboardingTelemetry(analytics: recorder, isPlus: { false })

    telemetry.notificationPermissionCompleted(granted: false)

    let completed = recorder.events.first { $0.event == .notificationPermissionCompleted }
    XCTAssertEqual(completed?.result, .denied)
  }
}
