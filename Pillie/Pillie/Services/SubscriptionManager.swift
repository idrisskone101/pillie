//
//  SubscriptionManager.swift
//  Pillie
//

import Foundation
import RevenueCat

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    // MARK: - Public State

    private(set) var isPlus = false
    private(set) var isLoading = false

    // MARK: - Constants

    static let apiKey = "appl_jAqXDkTjrIxXrqrDsPQInTuIsdp"
    static let entitlementID = "pillie_plus"
    static let monthlyProductID = "com.idrisskone.pillie.plus.monthly"
    static let annualProductID = "com.idrisskone.pillie.plus.annual"

    private override init() {
        super.init()
    }

    // MARK: - Configure (call once at app launch)

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)

        // Listen for subscription changes
        Purchases.shared.delegate = self

        Task { await refreshStatus() }
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        isPlus = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
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

    // MARK: - Refresh

    func refreshStatus() async {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
        isPlus = customerInfo.entitlements[Self.entitlementID]?.isActive == true
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
