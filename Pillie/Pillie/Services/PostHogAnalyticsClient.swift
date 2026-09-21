import Foundation
import PostHog

final class PostHogAnalyticsClient: ProductAnalyticsClient {
  /// PostHog's capture pipeline does non-trivial synchronous work on the calling
  /// thread. Every call site is a UI action on the main thread, and that work was
  /// measured at ~15ms per event on iOS 27 — enough to drop the first frame of any
  /// animation started in the same interaction (e.g. the tab-switch slide). A serial
  /// queue keeps events ordered while keeping their cost off the render-critical path.
  private let captureQueue = DispatchQueue(
    label: "com.idrisskone.pillie.posthog-capture",
    qos: .utility
  )

  func configure(_ configuration: ProductAnalyticsConfiguration) {
    let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
    config.captureApplicationLifecycleEvents = configuration.captureApplicationLifecycleEvents
    config.captureScreenViews = configuration.captureScreenViews
    config.enableSwizzling = configuration.enableSwizzling
    config.sendFeatureFlagEvent = configuration.sendFeatureFlagEvent
    config.preloadFeatureFlags = configuration.preloadFeatureFlags
    config.setDefaultPersonProperties = configuration.setDefaultPersonProperties
    config.optOut = configuration.isOptedOut
    config.personProfiles = configuration.personProfilesAlways ? .always : .identifiedOnly
    config.errorTrackingConfig.autoCapture = configuration.captureExceptions

    #if os(iOS)
      config.captureElementInteractions = configuration.captureElementInteractions
      config.sessionReplay = configuration.sessionReplay
      config.sessionReplayConfig.screenshotMode = configuration.sessionReplayScreenshotMode
      config.sessionReplayConfig.maskAllTextInputs = configuration.sessionReplayMaskAllTextInputs
      config.sessionReplayConfig.maskAllImages = configuration.sessionReplayMaskAllImages
      config.sessionReplayConfig.maskAllSandboxedViews =
        configuration.sessionReplayMaskAllSandboxedViews
      if #available(iOS 15.0, *) {
        config.surveys = configuration.surveys
      }
    #endif

    PostHogSDK.shared.setup(config)
  }

  func capture(
    event: String,
    properties: [String: AnalyticsPropertyValue],
    personProperties: [String: AnalyticsPropertyValue]
  ) {
    captureQueue.async {
      PostHogSDK.shared.capture(
        event,
        properties: properties.mapValues(\.postHogValue),
        userProperties: personProperties.isEmpty
          ? nil
          : personProperties.mapValues(\.postHogValue)
      )
    }
  }

  func captureException(_ error: Error, properties: [String: AnalyticsPropertyValue]) {
    captureQueue.async {
      PostHogSDK.shared.captureException(
        error,
        properties: properties.mapValues(\.postHogValue)
      )
    }
  }

  func distinctId() -> String? {
    PostHogSDK.shared.getDistinctId()
  }

  func flush() {
    captureQueue.async {
      PostHogSDK.shared.flush()
    }
  }
}
