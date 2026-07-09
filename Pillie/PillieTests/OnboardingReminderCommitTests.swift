//
//  OnboardingReminderCommitTests.swift
//  PillieTests
//
//  Covers the Reminder Time commit ordering (#196): production sessions showed
//  `UNUserNotificationCenter.add` firing before notification authorization was
//  requested, so iOS rejected every request with code 2003 ("Source is not
//  authorized") and PostHog recorded an error storm during onboarding. The
//  commit must persist the chosen time first, then resolve authorization, and
//  only schedule reminders after a grant.
//
//  Deliberately a plain (non-`@MainActor`) XCTestCase exercising a value type,
//  to avoid the Xcode 27 hosted-XCTest @MainActor deinit crash.
//

import XCTest

@testable import Pillie

final class OnboardingReminderCommitTests: XCTestCase {

  private enum Step: Equatable {
    case save(hour: Int, minute: Int)
    case authorizationRequested
    case schedule
    case permissionRequestedTracked
    case permissionCompletedTracked(granted: Bool)
  }

  func testCommitSavesReminderTimeBeforeRequestingAuthorization() {
    var steps: [Step] = []
    let commit = OnboardingReminderCommit(
      saveReminderTime: { hour, minute in steps.append(.save(hour: hour, minute: minute)) },
      trackPermissionRequested: {},
      requestAuthorization: { completion in
        steps.append(.authorizationRequested)
        completion(true)
      },
      trackPermissionCompleted: { _ in },
      scheduleReminders: {}
    )

    commit.run(hour: 21, minute: 30, completion: {})

    XCTAssertEqual(
      steps,
      [.save(hour: 21, minute: 30), .authorizationRequested],
      "The chosen time must be persisted before iOS authorization is requested, so it survives even if the user abandons the prompt."
    )
  }

  func testGrantedAuthorizationSchedulesRemindersOnlyAfterPermissionResolves() {
    var steps: [Step] = []
    var pendingAuthorization: ((Bool) -> Void)?
    let commit = OnboardingReminderCommit(
      saveReminderTime: { hour, minute in steps.append(.save(hour: hour, minute: minute)) },
      trackPermissionRequested: {},
      requestAuthorization: { completion in
        steps.append(.authorizationRequested)
        pendingAuthorization = completion
      },
      trackPermissionCompleted: { _ in },
      scheduleReminders: { steps.append(.schedule) }
    )

    commit.run(hour: 8, minute: 0, completion: {})

    XCTAssertFalse(
      steps.contains(.schedule),
      "No notification may be scheduled while the iOS permission prompt is still unresolved — that is the exact code-2003 error storm from #196."
    )

    pendingAuthorization?(true)

    XCTAssertEqual(
      steps,
      [.save(hour: 8, minute: 0), .authorizationRequested, .schedule],
      "Once the user grants permission, reminders must be scheduled."
    )
  }

  func testDeniedAuthorizationSkipsSchedulingAndStillContinues() {
    var steps: [Step] = []
    var continued = false
    let commit = OnboardingReminderCommit(
      saveReminderTime: { hour, minute in steps.append(.save(hour: hour, minute: minute)) },
      trackPermissionRequested: {},
      requestAuthorization: { completion in
        steps.append(.authorizationRequested)
        completion(false)
      },
      trackPermissionCompleted: { _ in },
      scheduleReminders: { steps.append(.schedule) }
    )

    commit.run(hour: 8, minute: 0, completion: { continued = true })

    XCTAssertFalse(
      steps.contains(.schedule),
      "A denial is product state, not an error — nothing may be scheduled, so no code-2003 storm is possible."
    )
    XCTAssertTrue(continued, "Onboarding must continue gracefully after a denial.")
  }

  func testPermissionTelemetryBracketsTheAuthorizationRequest() {
    var steps: [Step] = []
    let commit = OnboardingReminderCommit(
      saveReminderTime: { _, _ in },
      trackPermissionRequested: { steps.append(.permissionRequestedTracked) },
      requestAuthorization: { completion in
        steps.append(.authorizationRequested)
        completion(true)
      },
      trackPermissionCompleted: { granted in steps.append(.permissionCompletedTracked(granted: granted)) },
      scheduleReminders: { steps.append(.schedule) }
    )

    commit.run(hour: 8, minute: 0, completion: {})

    XCTAssertEqual(
      steps,
      [
        .permissionRequestedTracked,
        .authorizationRequested,
        .permissionCompletedTracked(granted: true),
        .schedule,
      ],
      "The funnel must show notification_permission_requested before any scheduling attempt (#196 acceptance criteria)."
    )
  }
}
