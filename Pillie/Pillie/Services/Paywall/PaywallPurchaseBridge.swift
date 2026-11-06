//
//  PaywallPurchaseBridge.swift
//  Pillie
//

import Foundation
import RevenueCat

enum PaywallPurchaseBridge {
    static func package(
        for intent: PaywallPurchaseIntent,
        offerings: Offerings?
    ) -> Package? {
        guard let offering = offerings?.current else { return nil }
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

    /// The extend SKU may sit in the current offering or a separate one, so
    /// every offering is scanned: current first, then the rest by identifier.
    static func extendPackage(offerings: Offerings?) -> Package? {
        guard let offerings else { return nil }
        return extendPackage(current: offerings.current, all: offerings.all)
    }

    static func extendPackage(current: Offering?, all: [String: Offering]) -> Package? {
        let others = all.values
            .filter { $0.identifier != current?.identifier }
            .sorted { $0.identifier < $1.identifier }
        let ordered = [current].compactMap { $0 } + others
        return ordered.lazy
            .flatMap(\.availablePackages)
            .first { $0.storeProduct.productIdentifier == SubscriptionManager.extendAnnualProductID }
    }
}
