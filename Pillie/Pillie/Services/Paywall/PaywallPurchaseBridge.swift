//
//  PaywallPurchaseBridge.swift
//  Pillie
//

import Foundation
import RevenueCat

enum PaywallPurchaseBridge {
    static func package(
        for intent: PaywallPurchaseIntent,
        offerings: Offerings?,
        selectedOffering: Offering? = nil
    ) -> Package? {
        guard let offering = selectedOffering ?? offerings?.current else { return nil }
        let plan = intent.pilliePlusPlan
        let preferredPackage = switch plan {
        case .annual: offering.annual
        case .monthly: offering.monthly
        case .lifetime: offering.lifetime
        }
        return PilliePlusPackageResolver.resolve(
            plan: plan,
            preferredPackage: preferredPackage,
            availablePackages: offering.availablePackages,
            productIdentifier: \Package.storeProduct.productIdentifier
        )
    }
}
