//
//  LifetimePlanTests.swift
//  PillieTests
//
//  Shared lifetime purchase-plan behavior for issue #257.
//

import Testing

@testable import Pillie

struct LifetimePlanTests {
    private struct StubPackage: Equatable {
        let productID: String
    }

    @Test func `Lifetime plan resolves the App Store product`() {
        #expect(PilliePlusPlan.lifetime.productID == "com.idrisskone.pillie.plus.lifetime")
        #expect(PilliePlusPlan.lifetime.analyticsPlan == .lifetime)
    }

    @Test func `Lifetime plan resolves its package from the current offering`() throws {
        let expected = StubPackage(productID: SubscriptionManager.lifetimeProductID)

        let package = PilliePlusPackageResolver.resolve(
            plan: .lifetime,
            preferredPackage: nil,
            availablePackages: [
                StubPackage(productID: SubscriptionManager.annualProductID),
                expected,
            ],
            productIdentifier: \StubPackage.productID
        )

        #expect(try #require(package) == expected)
    }
}
