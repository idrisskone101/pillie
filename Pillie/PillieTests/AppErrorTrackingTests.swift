//
//  AppErrorTrackingTests.swift
//  PillieTests
//
//  Error / exception tracking (#179): exception autocapture is switched on at
//  configure time, and handled failures flow through `trackError` as a PII-safe
//  `app_error` event plus a `$exception` capture for PostHog Error Tracking.
//

import XCTest

@testable import Pillie

// The Xcode 27 beta aborts hosted tests when any @MainActor class deallocates,
// and app-module classes are implicitly @MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION).
// Instances are parked in `retainedForProcessLifetime` so their deinit never
// runs under the beta bug; drop this once the toolchain is fixed.
@MainActor private var retainedForProcessLifetime: [AnyObject] = []

/// Keeps a value (and everything it retains) alive for the process lifetime.
private final class RetainBox {
  private let value: Any
  init(_ value: Any) { self.value = value }
}

@MainActor
final class AppErrorTrackingTests: XCTestCase {

  func testConfigureEnablesExceptionAutocapture() throws {
    let client = ErrorRecordingAnalyticsClient()
    let manager = makeManager(client: client)

    manager.configure()

    let configuration = try XCTUnwrap(client.configurations.first)
    XCTAssertTrue(configuration.captureExceptions)
  }

  func testTrackErrorCapturesAppErrorWithDomainMessageCodeAndSeverity() throws {
    let client = ErrorRecordingAnalyticsClient()
    let manager = makeManager(client: client)
    manager.configure()

    let error = NSError(
      domain: "PillieTestDomain", code: 42,
      userInfo: [NSLocalizedDescriptionKey: "offerings fetch timed out"]
    )
    manager.trackError(.offerings, error: error, context: ["operation": "fetch"])

    let capture = try XCTUnwrap(client.captures.first)
    XCTAssertEqual(capture.event, "app_error")
    XCTAssertEqual(
      capture.properties,
      [
        "domain": .string("offerings"),
        "message": .string("offerings fetch timed out"),
        "code": .int(42),
        "severity": .string("error"),
        "operation": .string("fetch"),
      ])
    XCTAssertTrue(capture.personProperties.isEmpty)
  }

  func testTrackErrorForwardsTheRawErrorToCaptureException() throws {
    let client = ErrorRecordingAnalyticsClient()
    let manager = makeManager(client: client)
    manager.configure()

    let error = NSError(domain: "PillieTestDomain", code: 7)
    manager.trackError(.notifications, error: error, severity: .warning)

    let exception = try XCTUnwrap(client.exceptions.first)
    XCTAssertEqual(exception.error as NSError, error)
    XCTAssertEqual(
      exception.properties,
      [
        "domain": .string("notifications"),
        "severity": .string("warning"),
      ])
  }

  func testTrackErrorNoOpsWhenUnconfigured() {
    let client = ErrorRecordingAnalyticsClient()
    let manager = AnalyticsManager(
      defaults: UserDefaults(suiteName: "AppErrorTrackingTests-\(UUID().uuidString)")!,
      client: client,
      infoDictionary: ["PostHogProjectToken": "   "]
    )
    retainedForProcessLifetime.append(manager)
    manager.configure()

    manager.trackError(.purchase, error: NSError(domain: "X", code: 1))

    XCTAssertTrue(client.captures.isEmpty)
    XCTAssertTrue(client.exceptions.isEmpty)
  }

  func testTelemetryTrackErrorForwardsWithErrorSeverityByDefault() throws {
    let recorder = ErrorRecordingTracker()
    let telemetry = ProductAnalyticsTelemetry(
      analytics: recorder,
      isPlus: { false },
      acquisitionSource: { nil }
    )
    // Park the struct's storage too — destroying it releases app-module closure
    // contexts, which trips the same beta deinit abort.
    retainedForProcessLifetime.append(RetainBox(telemetry))

    let error = NSError(domain: "PillieTestDomain", code: 3)
    telemetry.trackError(.screenTime, error: error, context: ["operation": "monitoring"])

    let tracked = try XCTUnwrap(recorder.errors.first)
    XCTAssertEqual(tracked.domain, .screenTime)
    XCTAssertEqual(tracked.error as NSError, error)
    XCTAssertEqual(tracked.context, ["operation": "monitoring"])
    XCTAssertEqual(tracked.severity, .error)
  }

  private func makeManager(client: ErrorRecordingAnalyticsClient) -> AnalyticsManager {
    let manager = AnalyticsManager(
      defaults: UserDefaults(suiteName: "AppErrorTrackingTests-\(UUID().uuidString)")!,
      client: client,
      infoDictionary: ["PostHogProjectToken": "phc_test_token"]
    )
    retainedForProcessLifetime.append(manager)
    return manager
  }
}

private final class ErrorRecordingTracker: AnalyticsTracking {
  private(set) var errors: [(
    domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  )] = []

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
    trialWarningDay: Int?,
    trialEndCohort: TrialEndPaywallCohort?,
    titleCustomized: Bool?,
    bodyCustomized: Bool?,
    retryTitleCustomized: Bool?,
    retryBodyCustomized: Bool?,
    lastCallTitleCustomized: Bool?,
    lastCallBodyCustomized: Bool?
  ) {}

  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  ) {
    errors.append((domain, error, context, severity))
  }
}

private final class ErrorRecordingAnalyticsClient: ProductAnalyticsClient {
  private(set) var configurations: [ProductAnalyticsConfiguration] = []
  private(set) var captures: [(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  )] = []
  private(set) var exceptions: [(
    error: Error,
    properties: [String: AnalyticsPropertyValue]
  )] = []

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    configurations.append(configuration)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {
    captures.append((event, properties, personProperties))
  }

  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue]) {
    exceptions.append((error, properties))
  }

  func distinctId() -> String? { "test-distinct-id" }

  func flush() {}
}
