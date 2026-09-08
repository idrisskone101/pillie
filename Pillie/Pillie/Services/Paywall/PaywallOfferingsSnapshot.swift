//
//  PaywallOfferingsSnapshot.swift
//  Pillie
//

import Foundation
import RevenueCat

struct PaywallOfferingsSnapshot: Equatable {
    let annualPrice: Decimal
    let monthlyPrice: Decimal
    let lifetimePrice: Decimal?
    let annualDisplay: String
    let monthlyDisplay: String
    let lifetimeDisplay: String?
    let currencyCode: String?

    static func parse(_ offerings: Offerings?) -> PaywallOfferingsSnapshot? {
        guard let offering = offerings?.current else { return nil }

        guard let annualPackage = PilliePlusPackageResolver.resolve(
            plan: .annual,
            preferredPackage: offering.annual,
            availablePackages: offering.availablePackages,
            productIdentifier: \Package.storeProduct.productIdentifier
        ),
        let monthlyPackage = PilliePlusPackageResolver.resolve(
            plan: .monthly,
            preferredPackage: offering.monthly,
            availablePackages: offering.availablePackages,
            productIdentifier: \Package.storeProduct.productIdentifier
        ) else {
            return nil
        }

        let annualProduct = annualPackage.storeProduct
        let monthlyProduct = monthlyPackage.storeProduct
        let lifetimePackage = PilliePlusPackageResolver.resolve(
            plan: .lifetime,
            preferredPackage: offering.lifetime,
            availablePackages: offering.availablePackages,
            productIdentifier: \Package.storeProduct.productIdentifier
        )

        return PaywallOfferingsSnapshot(
            annualPrice: annualProduct.price,
            monthlyPrice: monthlyProduct.price,
            lifetimePrice: lifetimePackage?.storeProduct.price,
            annualDisplay: annualProduct.localizedPriceString,
            monthlyDisplay: monthlyProduct.localizedPriceString,
            lifetimeDisplay: lifetimePackage?.storeProduct.localizedPriceString,
            currencyCode: annualProduct.currencyCode
        )
    }

    static func fixture(
        annualDisplay: String,
        monthlyDisplay: String,
        lifetimeDisplay: String?,
        annual: Decimal,
        monthly: Decimal,
        lifetime: Decimal?
    ) -> PaywallOfferingsSnapshot {
        PaywallOfferingsSnapshot(
            annualPrice: annual,
            monthlyPrice: monthly,
            lifetimePrice: lifetime,
            annualDisplay: annualDisplay,
            monthlyDisplay: monthlyDisplay,
            lifetimeDisplay: lifetimeDisplay,
            currencyCode: "USD"
        )
    }
}
