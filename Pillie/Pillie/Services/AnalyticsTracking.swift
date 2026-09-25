import Foundation

protocol AnalyticsTracking {
  func track(_ event: AnalyticsEvent, payload: AnalyticsPayload)

  /// Report a handled failure as `app_error` + `$exception` (#179).
  func trackError(
    _ domain: AppErrorDomain,
    error: Error,
    context: [String: String],
    severity: AppErrorSeverity
  )
}
