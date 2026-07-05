//
//  SessionReplayConfigurationTests.swift
//  PillieTests
//
//  Covers enabling PostHog session replay (#175). Lives in its own suite (not
//  AnalyticsManagerTests, which currently crashes wholesale on the Xcode 27
//  beta's hosted-XCTest deinit abort) and follows the stable pattern: no
//  setUp/tearDown deallocation, every fixture retained for the process
//  lifetime.
//

import XCTest

@testable import Pillie

final class SessionReplayConfigurationTests: XCTestCase {

  func testConfigureEnablesAggressivelyMaskedSessionReplay() throws {
    // Session replay is on (#175) with every masking control engaged — this is
    // a health app, so pill names and health data must never be recorded — and
    // screenshot mode, which PostHog requires for SwiftUI capture.
    let client = ReplaySpyClient()
    let manager = makeManager(client: client)

    manager.configure()

    let configuration = try XCTUnwrap(client.configurations.first)
    XCTAssertTrue(configuration.sessionReplay)
    XCTAssertTrue(configuration.sessionReplayScreenshotMode)
    XCTAssertTrue(configuration.sessionReplayMaskAllTextInputs)
    XCTAssertTrue(configuration.sessionReplayMaskAllImages)
    XCTAssertTrue(configuration.sessionReplayMaskAllSandboxedViews)
  }

  // MARK: - Helpers

  private static var keptObjects: [AnyObject] = []

  private func makeManager(client: ReplaySpyClient) -> AnalyticsManager {
    let defaults = UserDefaults(suiteName: "SessionReplayTests-\(UUID().uuidString)")!
    let manager = AnalyticsManager(
      defaults: defaults,
      client: client,
      infoDictionary: [
        "PostHogProjectToken": "phc_test_token",
        "PostHogHost": "https://us.i.posthog.com",
      ])
    Self.keptObjects.append(defaults)
    Self.keptObjects.append(manager)
    return manager
  }
}

private final class ReplaySpyClient: ProductAnalyticsClient {
  private static var keepAlive: [ReplaySpyClient] = []

  private(set) var configurations: [ProductAnalyticsConfiguration] = []

  init() {
    Self.keepAlive.append(self)
  }

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    configurations.append(configuration)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {}

  func distinctId() -> String? { nil }

  func flush() {}
}
