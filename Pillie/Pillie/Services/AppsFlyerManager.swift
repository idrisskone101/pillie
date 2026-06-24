//
//  AppsFlyerManager.swift
//  Pillie
//

import Foundation
import UIKit
import AppsFlyerLib
import AppTrackingTransparency
import os

/// Owns AppsFlyer SDK setup and the install/session ("launch") reporting that
/// powers acquisition attribution.
///
/// Mirrors `AnalyticsManager` (PostHog): a `shared` singleton configured once at
/// launch, reading its key from Info.plist via build-setting substitution
/// (`AppsFlyerDevKey` = `$(APPSFLYER_DEV_KEY)`), and failing *loudly* — never
/// silently — when the key is missing.
///
/// Lifecycle, per AppsFlyer's iOS SDK guide:
/// - Keys + delegate are set in `application(_:didFinishLaunchingWithOptions:)`.
/// - `start()` is sent on every `UIApplication.didBecomeActive` so each foreground
///   logs a session. A SwiftUI app with an `AppDelegate` never receives
///   `applicationDidBecomeActive`, so we observe the notification instead.
///
/// ATT: the prompt is shown on first foreground. `waitForATTUserAuthorization`
/// holds the first session until the user answers (or 60s elapses) so the IDFA —
/// when granted — is attached to the install; this feeds the SKAN conversion model.
/// Requires `NSUserTrackingUsageDescription` in Info.plist.
///
/// The AppsFlyer dev key is account-level and safe to embed in the client binary,
/// but — like the PostHog key — it is kept out of git and injected via the
/// gitignored `Config/Secrets.xcconfig`.
final class AppsFlyerManager: NSObject {
    static let shared = AppsFlyerManager()

    /// Public Apple App ID for "Pillie: Birth Control Reminder" (AppsFlyer app
    /// `id6759352439`). Digits only — AppsFlyer rejects an `id` prefix.
    private let appleAppID = "6759352439"

    private let log = Logger(subsystem: "com.idrisskone.pillie", category: "AppsFlyer")

    private var isConfigured = false

    /// `true` when `configure()` ran but found no usable `AppsFlyerDevKey`, so the
    /// SDK was never started and no installs are reported. Surfaced (not silent) for
    /// the same reason `AnalyticsManager.didFailConfiguration` is: a missing key that
    /// fails quietly stays invisible until attribution looks broken.
    private(set) var didFailConfiguration = false

    private override init() {}

    private var isDebugLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Configure and arm AppsFlyer. Call once, from
    /// `application(_:didFinishLaunchingWithOptions:)`, outside test runs.
    func configure() {
        guard !isConfigured else { return }

        // Verbose [AppsFlyerSDK] logs in development only; never leak SDK internals
        // from a shipping build. Set before any other SDK call so early logs survive.
        AppsFlyerLib.shared().isDebug = isDebugLoggingEnabled

        guard let devKey = infoDictionaryString("AppsFlyerDevKey") else {
            reportConfigurationFailure()
            return
        }

        AppsFlyerLib.shared().appsFlyerDevKey = devKey
        AppsFlyerLib.shared().appleAppID = appleAppID
        AppsFlyerLib.shared().delegate = self

        // Hold the install/session send until the ATT prompt is answered (up to 60s)
        // so the IDFA — when granted — is attached to the install. The SKAN conversion
        // model keys off attributed installs + real revenue, so this matters.
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)

        // SwiftUI apps with an AppDelegate don't get applicationDidBecomeActive, so
        // observe the notification and send the launch from there.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sendLaunch),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        isConfigured = true
        log.notice("AppsFlyer configured (appleAppID=\(self.appleAppID, privacy: .public)).")
    }

    @objc private func sendLaunch() {
        requestTrackingAuthorizationIfNeeded()
        AppsFlyerLib.shared().start(completionHandler: { [weak self] response, error in
            guard let self else { return }
            if let error {
                self.log.error("AppsFlyer launch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            self.log.notice("AppsFlyer launch sent — server accepted the session. response=\(String(describing: response), privacy: .public)")
        })
    }

    private var didRequestATT = false

    /// Present the ATT prompt once per process. iOS only actually shows it while the
    /// status is `.notDetermined`; later calls resolve immediately. Must run while the
    /// app is active — we call it from the didBecomeActive observer.
    private func requestTrackingAuthorizationIfNeeded() {
        guard !didRequestATT else { return }
        didRequestATT = true
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            self?.log.notice("AppsFlyer ATT status=\(Int(status.rawValue), privacy: .public) (0=notDetermined,1=restricted,2=denied,3=authorized)")
        }
    }

    private func reportConfigurationFailure() {
        didFailConfiguration = true
        log.fault("AppsFlyerDevKey missing or empty — AppsFlyer disabled and no installs will be reported. Set APPSFLYER_DEV_KEY (Config/Secrets.xcconfig).")
    }

    /// The AppsFlyer device ID. Shared with RevenueCat (`setAppsflyerID`) so both
    /// platforms join the same user. Empty until the SDK has initialized.
    var appsFlyerUID: String { AppsFlyerLib.shared().getAppsFlyerUID() }

    // MARK: - Conversion events
    //
    // Mapped to the af_ names used in the TikTok / SKAN postback config. Fire these
    // alongside the matching PostHog events. All no-op until `configure()` succeeds.

    /// `af_purchase` — a real paid conversion. Revenue MUST be the actual price (never
    /// 0) and `currency` an ISO 4217 code: the SKAN conversion model keys off them.
    func logPurchase(revenue: Double, currency: String, productId: String) {
        guard isConfigured else { return }
        // Revenue MUST be a real, positive amount. A 0/missing value collapses the
        // SKAN revenue-range model, so refuse to send a malformed purchase rather than
        // poison iOS measurement — and make it loud.
        guard revenue > 0 else {
            log.fault("AppsFlyer af_purchase suppressed — revenue must be > 0 (got \(String(revenue), privacy: .public)) for product \(productId, privacy: .public); a 0/missing value collapses SKAN measurement.")
            return
        }
        AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
            AFEventParamRevenue: revenue,
            AFEventParamCurrency: currency,
            AFEventParamContentId: productId,
        ])
        log.notice("AppsFlyer af_purchase revenue=\(String(revenue), privacy: .public) currency=\(currency, privacy: .public) product=\(productId, privacy: .public)")
    }

    /// `af_start_trial` — a free trial began.
    func logStartTrial(currency: String, productId: String) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(AFEventStartTrial, withValues: [
            AFEventParamCurrency: currency,
            AFEventParamContentId: productId,
        ])
        log.notice("AppsFlyer af_start_trial currency=\(currency, privacy: .public) product=\(productId, privacy: .public)")
    }

    /// `af_complete_registration` — onboarding completed.
    func logCompleteRegistration() {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: [:])
        log.notice("AppsFlyer af_complete_registration")
    }

    /// Read a string from Info.plist, treating an unsubstituted `$(...)` build
    /// variable or an empty value as absent. Same guard as `AnalyticsManager`.
    private func infoDictionaryString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}

extension AppsFlyerManager: AppsFlyerLibDelegate {
    /// Fires once attribution resolves on install/open. Cached after first success.
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let status = conversionInfo["af_status"] as? String ?? "unknown"
        let mediaSource = conversionInfo["media_source"] as? String ?? "n/a"
        let isFirstLaunch = String(describing: conversionInfo["is_first_launch"] ?? "n/a")
        log.notice("AppsFlyer onConversionDataSuccess: af_status=\(status, privacy: .public), media_source=\(mediaSource, privacy: .public), is_first_launch=\(isFirstLaunch, privacy: .public)")
        #if DEBUG
        log.debug("AppsFlyer conversion payload: \(String(describing: conversionInfo), privacy: .public)")
        #endif
    }

    func onConversionDataFail(_ error: Error) {
        log.error("AppsFlyer onConversionDataFail: \(error.localizedDescription, privacy: .public)")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        log.notice("AppsFlyer onAppOpenAttribution: \(String(describing: attributionData), privacy: .public)")
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        log.error("AppsFlyer onAppOpenAttributionFailure: \(error.localizedDescription, privacy: .public)")
    }
}
