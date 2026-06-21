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

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    // MARK: - Public State

    private(set) var isPlus = false
    private(set) var isLoading = false

    // MARK: - Constants

    static let apiKey = "appl_jAqXDkTjrIxXrqrDsPQInTuIsdp"
    nonisolated static let entitlementID = "pillie_plus"
    static let monthlyProductID = "com.idrisskone.pillie.plus.monthly"
    static let annualProductID = "com.idrisskone.pillie.plus.annual"
    private var isConfigured = false

    private override init() {
        super.init()
    }

    // MARK: - Configure (call once at app launch)

    func configure() {
        guard !isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true

        // Listen for subscription changes
        Purchases.shared.delegate = self

        Task { await refreshStatus() }
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        try applyPurchaseResult(
            userCancelled: result.userCancelled,
            isPlusEntitlementActive: result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        )
    }

    // MARK: - Restore

    func restore() async throws {
        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        isPlus = customerInfo.entitlements[Self.entitlementID]?.isActive == true
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
        isPlus = customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }

    #if DEBUG
    func setPlusForTesting(_ isPlus: Bool) {
        self.isPlus = isPlus
    }
    #endif

    func applyPurchaseResult(userCancelled: Bool, isPlusEntitlementActive: Bool) throws {
        if userCancelled {
            throw SubscriptionPurchaseError.userCancelled
        }

        guard isPlusEntitlementActive else {
            isPlus = false
            throw SubscriptionPurchaseError.missingPlusEntitlement
        }

        isPlus = true
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        Task { @MainActor in
            self.isPlus = active
        }
    }
}
