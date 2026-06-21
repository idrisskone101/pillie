//
//  SubscriptionManager.swift
//  Pillie
//

import Foundation
import RevenueCat

enum SubscriptionPurchaseError: Error, Equatable, LocalizedError {
    case userCancelled
    case missingPlusEntitlement

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled."
        case .missingPlusEntitlement:
            return "The purchase finished, but Pillie Plus was not activated. Please try again or restore purchases."
        }
    }
}

/// The paid-conversion telemetry that a successful purchase should emit.
enum SubscriptionConversionEvent: Equatable {
    /// A free trial began — its own funnel step, distinct from a paid charge.
    case trialStarted
    /// A real, immediate paid charge.
    case purchaseCompleted
}

/// What a successful `purchase` actually was, so the paywall can record the right
/// (or no) analytics event. The classification is a pure value type so the
/// trial/paid/sandbox decision is unit-testable without RevenueCat.
struct PurchaseOutcome: Equatable {
    /// The active entitlement is in its trial period (`PeriodType.trial`).
    let isTrial: Bool
    /// The transaction came from the StoreKit/RevenueCat sandbox (dev, TestFlight,
    /// App Review). Never a real payer, so it must not inflate paid metrics.
    let isSandbox: Bool

    /// The conversion event to record, or `nil` to suppress it. Sandbox transactions
    /// emit nothing; otherwise a trial and a paid charge are distinct events.
    var conversionEvent: SubscriptionConversionEvent? {
        guard !isSandbox else { return nil }
        return isTrial ? .trialStarted : .purchaseCompleted
    }
}

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    // MARK: - Public State

    private(set) var isPlus = false
    private(set) var isLoading = false

    /// Fired whenever the Plus entitlement actually flips (upgrade or churn), never on
    /// a no-op refresh. Wired at launch to re-plan Smart Reminders immediately so the
    /// change takes effect without waiting for the next natural reschedule (ADR 0004).
    /// `@ObservationIgnored` because it is a side-effect hook, not observable UI state.
    @ObservationIgnored
    var onEntitlementChange: ((Bool) -> Void)?

    // MARK: - Constants

    static let apiKey = "appl_jAqXDkTjrIxXrqrDsPQInTuIsdp"
    nonisolated static let entitlementID = "pillie_plus"
    static let monthlyProductID = "com.idrisskone.pillie.plus.monthly"
    static let annualProductID = "com.idrisskone.pillie.plus.annual"
    private var isConfigured = false

    private override init() {
        super.init()
    }

    /// Single funnel for every entitlement mutation. Updates `isPlus` and fires
    /// `onEntitlementChange` only when the value actually flips, so refreshes that
    /// re-confirm the same state never trigger a redundant reschedule.
    private func setIsPlus(_ newValue: Bool) {
        guard isPlus != newValue else { return }
        isPlus = newValue
        onEntitlementChange?(newValue)
    }

    // MARK: - Configure (call once at app launch)

    func configure() {
        guard !isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true

        // Listen for subscription changes
        Purchases.shared.delegate = self

        applyAttribution()
        Task { await refreshStatus() }
    }

    /// Ties RevenueCat to the in-app analytics person and tags the subscriber with the
    /// coarse acquisition source. Setting the PostHog distinct id (`$posthogUserId`)
    /// lets RevenueCat's PostHog integration land server-side subscription events
    /// (renewals, trial→paid conversions) on the same person as the in-app funnel; the
    /// `acquisition_source` attribute lets paid conversions be segmented by source.
    /// Reads the source from the value PillStore already persisted during onboarding,
    /// so it is applied whenever RevenueCat configures (at launch or before the paywall),
    /// regardless of whether RevenueCat existed when the user answered the step.
    private func applyAttribution() {
        if let distinctId = AnalyticsManager.shared.distinctId, !distinctId.isEmpty {
            Purchases.shared.attribution.setPostHogUserID(distinctId)
        }
        if let source = UserDefaults.standard.string(forKey: PillStore.acquisitionSourceKey),
           !source.isEmpty {
            Purchases.shared.attribution.setAttributes(["acquisition_source": source])
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        let entitlement = result.customerInfo.entitlements[Self.entitlementID]
        try applyPurchaseResult(
            userCancelled: result.userCancelled,
            isPlusEntitlementActive: entitlement?.isActive == true
        )
        return PurchaseOutcome(
            isTrial: entitlement?.periodType == .trial,
            isSandbox: entitlement?.isSandbox ?? false
        )
    }

    // MARK: - Restore

    func restore() async throws {
        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        setIsPlus(customerInfo.entitlements[Self.entitlementID]?.isActive == true)
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    /// Warm RevenueCat + the offerings cache ahead of the paywall. Called a couple
    /// of screens before the paywall (the diagnosis reveal) so that, by the time the
    /// paywall appears, `fetchOfferings()` returns from cache instead of doing a cold
    /// network round-trip while the user waits on a spinner. Idempotent and safe to
    /// call repeatedly: `configure()` guards itself and RevenueCat caches offerings.
    func prefetchOfferings() {
        configure()
        Task { _ = try? await fetchOfferings() }
    }

    // MARK: - Refresh

    func refreshStatus() async {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
        setIsPlus(customerInfo.entitlements[Self.entitlementID]?.isActive == true)
    }

    #if DEBUG
    func setPlusForTesting(_ isPlus: Bool) {
        setIsPlus(isPlus)
    }
    #endif

    func applyPurchaseResult(userCancelled: Bool, isPlusEntitlementActive: Bool) throws {
        if userCancelled {
            throw SubscriptionPurchaseError.userCancelled
        }

        guard isPlusEntitlementActive else {
            setIsPlus(false)
            throw SubscriptionPurchaseError.missingPlusEntitlement
        }

        setIsPlus(true)
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        Task { @MainActor in
            self.setIsPlus(active)
        }
    }
}
