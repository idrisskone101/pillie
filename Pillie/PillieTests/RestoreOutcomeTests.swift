//
//  RestoreOutcomeTests.swift
//  PillieTests
//
//  ENG-74: the restore error classifier and the one event each restore outcome
//  records on every restore surface, asserted on the PostHog wire payload.
//

import Foundation
import RevenueCat
import Testing

@testable import Pillie

@MainActor
struct RestoreErrorCategoryTests {
    @Test func `Storefront unavailable is a configuration failure`() {
        #expect(RestoreErrorCategory(error: SubscriptionPurchaseError.storefrontUnavailable) == .configuration)
    }

    @Test func `Other purchase errors are unknown`() {
        #expect(RestoreErrorCategory(error: SubscriptionPurchaseError.missingPlusEntitlement) == .unknown)
    }

    @Test func `Thrown RevenueCat codes classify by case`() {
        #expect(RestoreErrorCategory(error: ErrorCode.networkError) == .network)
        #expect(RestoreErrorCategory(error: ErrorCode.offlineConnectionError) == .network)
        #expect(RestoreErrorCategory(error: ErrorCode.storeProblemError) == .store)
        #expect(RestoreErrorCategory(error: ErrorCode.invalidReceiptError) == .store)
        #expect(RestoreErrorCategory(error: ErrorCode.purchaseNotAllowedError) == .store)
        #expect(RestoreErrorCategory(error: ErrorCode.configurationError) == .configuration)
        #expect(RestoreErrorCategory(error: ErrorCode.invalidCredentialsError) == .configuration)
        #expect(RestoreErrorCategory(error: ErrorCode.unknownBackendError) == .unknown)
    }

    @Test func `RevenueCat NSErrors classify by their code`() {
        #expect(RestoreErrorCategory(error: revenueCatNSError(.offlineConnectionError)) == .network)
        #expect(RestoreErrorCategory(error: revenueCatNSError(.receiptAlreadyInUseError)) == .store)
        #expect(RestoreErrorCategory(error: revenueCatNSError(.invalidAppleSubscriptionKeyError)) == .configuration)
        #expect(RestoreErrorCategory(error: revenueCatNSError(.unknownError)) == .unknown)
    }

    @Test func `URL loading errors are network failures`() {
        #expect(RestoreErrorCategory(error: URLError(.notConnectedToInternet)) == .network)
        #expect(RestoreErrorCategory(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)) == .network)
    }

    @Test func `Foreign errors are unknown`() {
        #expect(RestoreErrorCategory(error: NSError(domain: "com.example.other", code: 10)) == .unknown)
    }

    private func revenueCatNSError(_ code: ErrorCode) -> NSError {
        NSError(domain: "RevenueCat.ErrorCode", code: code.rawValue)
    }
}

@MainActor
struct RestoreTelemetryTests {
    /// Every restore surface, with the `surface` and `source` it must send.
    enum Surface: CaseIterable {
        case settingsPaywall
        case trialEndPaywall
        case plusUpsell
        case onboardingVerification

        var expectedSurface: String {
            switch self {
            case .settingsPaywall: "settings_subscription"
            case .trialEndPaywall: "trial_end"
            case .plusUpsell: "plus_upsell"
            case .onboardingVerification: "onboarding_verification"
            }
        }

        var expectedSource: String {
            switch self {
            case .settingsPaywall: "settings"
            case .trialEndPaywall: "trial_end"
            case .plusUpsell: "upsell"
            case .onboardingVerification: "onboarding"
            }
        }

        func start(_ telemetry: ProductAnalyticsTelemetry) {
            switch self {
            case .trialEndPaywall:
                telemetry.trialEndRestoreStarted(cohort: .blockerConfigured, terms: .hardPaywall)
            case .settingsPaywall:
                telemetry.restoreStarted(surface: .settingsSubscription)
            case .plusUpsell:
                telemetry.restoreStarted(surface: .plusUpsell)
            case .onboardingVerification:
                telemetry.restoreStarted(surface: .onboardingVerification)
            }
        }

        func finish(_ outcome: RestoreOutcome, _ telemetry: ProductAnalyticsTelemetry) {
            switch self {
            case .trialEndPaywall:
                telemetry.trialEndRestoreFinished(outcome, cohort: .blockerConfigured, terms: .hardPaywall)
            case .settingsPaywall:
                telemetry.restoreFinished(outcome, surface: .settingsSubscription)
            case .plusUpsell:
                telemetry.restoreFinished(outcome, surface: .plusUpsell)
            case .onboardingVerification:
                telemetry.restoreFinished(outcome, surface: .onboardingVerification)
            }
        }
    }

    // Xcode 27 beta: deallocating a @MainActor class mid-run aborts the host, so
    // every spy and manager lives for the process.
    private static var keptObjects: [AnyObject] = []

    @Test(arguments: Surface.allCases)
    func `Restore started carries the surface`(surface: Surface) {
        let client = makeClient(surface, "started")

        surface.start(client.telemetry)

        #expect(client.spy.events.map(\.name) == ["restore_started"])
        #expect(client.spy.events[0].properties["surface"] == .string(surface.expectedSurface))
        #expect(client.spy.events[0].properties["source"] == .string(surface.expectedSource))
        #expect(client.spy.events[0].properties["reason"] == nil)
        #expect(client.spy.events[0].properties["error_category"] == nil)
    }

    @Test(arguments: Surface.allCases)
    func `A restored purchase records restore_succeeded`(surface: Surface) {
        let client = makeClient(surface, "restored")

        surface.finish(.restored, client.telemetry)

        #expect(client.spy.events.map(\.name) == ["restore_succeeded"])
        let properties = client.spy.events[0].properties
        #expect(properties["surface"] == .string(surface.expectedSurface))
        #expect(properties["source"] == .string(surface.expectedSource))
        #expect(properties["result"] == .string("completed"))
        #expect(properties["reason"] == nil)
        #expect(properties["error_category"] == nil)
    }

    @Test(arguments: Surface.allCases)
    func `No active purchase records restore_completed with a reason`(surface: Surface) {
        let client = makeClient(surface, "none")

        surface.finish(.noActivePurchase, client.telemetry)

        #expect(client.spy.events.map(\.name) == ["restore_completed"])
        let properties = client.spy.events[0].properties
        #expect(properties["surface"] == .string(surface.expectedSurface))
        #expect(properties["reason"] == .string("no_active_purchase"))
        #expect(properties["error_category"] == nil)
    }

    @Test(arguments: Surface.allCases)
    func `A failed restore records restore_failed with its category and an app_error`(surface: Surface) {
        let client = makeClient(surface, "failed")

        surface.finish(.failed(RestoreFailure(error: URLError(.notConnectedToInternet))), client.telemetry)

        #expect(client.spy.events.map(\.name) == ["restore_failed", "app_error"])
        let properties = client.spy.events[0].properties
        #expect(properties["surface"] == .string(surface.expectedSurface))
        #expect(properties["result"] == .string("failed"))
        #expect(properties["error_category"] == .string("network"))
        #expect(properties["reason"] == nil)
        #expect(client.spy.events[1].properties["domain"] == .string("restore"))
    }

    @Test func `Trial-end restores keep the cohort`() {
        let client = makeClient(.trialEndPaywall, "cohort")

        Surface.trialEndPaywall.finish(.noActivePurchase, client.telemetry)

        #expect(client.spy.events[0].properties["cohort"] == .string("blocker_configured"))
        #expect(client.spy.events[0].properties["trial_terms_cohort"] == .string("post_cutover"))
    }

    private func makeClient(
        _ surface: Surface,
        _ name: String
    ) -> (telemetry: ProductAnalyticsTelemetry, spy: ProductAnalyticsSpy) {
        let spy = ProductAnalyticsSpy()
        let defaultsName = "RestoreTelemetryTests.\(surface).\(name)"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: spy,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(analytics)
        analytics.configure()
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            trialTermsCohort: { .postCutover }
        )
        return (telemetry, spy)
    }
}

@MainActor
struct OpenLineRestoreIssueTests {
    private let diagnostics = OpenLine.Diagnostics(
        appVersion: "2.1.1",
        build: "403",
        systemVersion: "27.0",
        deviceModel: "iPhone17,1"
    )

    @Test func `Restore issue mail has its own inbox subject and the issue report body`() throws {
        let english = Locale(identifier: "en")
        let url = try #require(OpenLine.mailURL(for: .restoreIssue(diagnostics), locale: english))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(url.scheme == "mailto")
        #expect(items.first { $0.name == "subject" }?.value == "Pillie — Restore Purchases")
        #expect(
            items.first { $0.name == "body" }?.value
                == OpenLine.Intent.issueReport(diagnostics).localizedBody(locale: english)
        )
        #expect(items.first { $0.name == "body" }?.value?.contains("iPhone17,1") == true)
    }
}
