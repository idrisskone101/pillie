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
    /// Days of the Annual product's free-trial intro offer, nil when it has none.
    /// Whether this person may still redeem it is a separate eligibility check.
    var annualIntroFreeDays: Int? = nil

    /// The onboarding paywall promises exactly "7 days free", and only once RevenueCat
    /// confirms this Apple Account can still redeem the intro offer.
    func offersAnnualFreeWeek(eligibility: TrialEndExtendEligibility) -> Bool {
        annualIntroFreeDays == 7 && eligibility == .eligible
    }

    static func parse(_ offering: Offering?) -> PaywallOfferingsSnapshot? {
        guard let offering else { return nil }

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
            currencyCode: annualProduct.currencyCode,
            annualIntroFreeDays: annualProduct.introductoryDiscount.flatMap { intro in
                TrialEndExtendProduct.freeDays(
                    paymentMode: intro.paymentMode,
                    period: intro.subscriptionPeriod,
                    numberOfPeriods: intro.numberOfPeriods
                )
            }
        )
    }

    #if DEBUG
    func withLifetimeDisplay(_ display: String) -> PaywallOfferingsSnapshot {
        PaywallOfferingsSnapshot(
            annualPrice: annualPrice,
            monthlyPrice: monthlyPrice,
            lifetimePrice: lifetimePrice,
            annualDisplay: annualDisplay,
            monthlyDisplay: monthlyDisplay,
            lifetimeDisplay: display,
            currencyCode: currencyCode,
            annualIntroFreeDays: annualIntroFreeDays
        )
    }
    #endif

    static func fixture(
        annualDisplay: String,
        monthlyDisplay: String,
        lifetimeDisplay: String?,
        annual: Decimal,
        monthly: Decimal,
        lifetime: Decimal?,
        annualIntroFreeDays: Int? = nil
    ) -> PaywallOfferingsSnapshot {
        PaywallOfferingsSnapshot(
            annualPrice: annual,
            monthlyPrice: monthly,
            lifetimePrice: lifetime,
            annualDisplay: annualDisplay,
            monthlyDisplay: monthlyDisplay,
            lifetimeDisplay: lifetimeDisplay,
            currencyCode: "USD",
            annualIntroFreeDays: annualIntroFreeDays
        )
    }
}
