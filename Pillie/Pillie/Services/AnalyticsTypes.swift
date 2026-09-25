import Foundation

enum AnalyticsPropertyValue: Equatable {
  case string(String)
  case bool(Bool)
  case int(Int)

  var postHogValue: Any {
    switch self {
    case .string(let value):
      return value
    case .bool(let value):
      return value
    case .int(let value):
      return value
    }
  }
}

struct ProductAnalyticsConfiguration: Equatable {
  let projectToken: String
  let host: String
  let captureApplicationLifecycleEvents: Bool
  let captureScreenViews: Bool
  let captureElementInteractions: Bool
  let enableSwizzling: Bool
  let sendFeatureFlagEvent: Bool
  let preloadFeatureFlags: Bool
  let setDefaultPersonProperties: Bool
  let sessionReplay: Bool
  /// PostHog captures SwiftUI replay via periodic screenshots; wireframe mode
  /// cannot see SwiftUI content, so replay requires screenshot mode here.
  let sessionReplayScreenshotMode: Bool
  // Masking controls (#175). This is a health app: pill names, schedules, and
  // health answers must never appear in a recording, so every masking control
  // ships engaged.
  let sessionReplayMaskAllTextInputs: Bool
  let sessionReplayMaskAllImages: Bool
  let sessionReplayMaskAllSandboxedViews: Bool
  let surveys: Bool
  let isOptedOut: Bool
  /// Process person profiles for every event (PostHog `personProfiles = .always`).
  /// Required so that person properties set via `$set` — notably `acquisition_source`
  /// — stick for anonymous users (we never call `identify`, per ADR 0001), letting the
  /// funnel be broken down by source. Default PostHog behavior (`.identifiedOnly`) drops
  /// `$set` for users who never identify.
  let personProfilesAlways: Bool
  /// Auto-capture uncaught NSExceptions / Swift errors as `$exception` events
  /// (PostHog `errorTrackingConfig.autoCapture`), giving the founder dashboard a
  /// crash-rate signal (#179).
  let captureExceptions: Bool
}

protocol ProductAnalyticsClient: AnyObject {
  func configure(_ configuration: ProductAnalyticsConfiguration)
  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  )
  /// Capture a handled error as a `$exception` event so it groups in PostHog
  /// Error Tracking with a stack-classified fingerprint (#179).
  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue])
  /// The current anonymous distinct id, used to join server-side RevenueCat events
  /// to the same PostHog person. `nil` before the SDK is configured.
  func distinctId() -> String?
  func flush()
}

/// The failing subsystem carried as `domain` on `app_error`, kept a closed
/// low-cardinality enum (never a raw string) so the "Errors by domain" dashboard
/// panel stays plottable and no free-form text can leak PII (#179).
enum AppErrorDomain: String {
  /// StoreKit / RevenueCat purchase flow failures (excluding user cancels).
  case purchase
  /// RevenueCat restore-purchases failures.
  case restore
  /// RevenueCat offerings fetch failures (paywall spinner dead-ends).
  case offerings
  /// Screen Time / FamilyControls authorization and monitoring failures.
  case screenTime = "screen_time"
  /// Local notification authorization and scheduling failures.
  case notifications
  /// Deliberate QA errors fired from the DEBUG smoke deep link.
  case debug
}

/// Coarse severity on `app_error` so the dashboard can split noise (`warning`)
/// from real failures (`error`) and crashes surfaced manually (`fatal`).
enum AppErrorSeverity: String {
  case warning
  case error
  case fatal
}

// The client grew `captureException` for #179; a default no-op keeps the many
// test spies compiling. `PostHogAnalyticsClient` overrides it for real capture.
extension ProductAnalyticsClient {
  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue]) {}
}
