//
//  PaywallPriceComparison.swift
//  Pillie
//
//  Pure, testable derivation of the annual-vs-monthly comparison shown on the
//  paywall. Both the "$X/mo" equivalent and the "N months free" badge are computed from
//  the real StoreKit / RevenueCat prices, so the paywall never shows a hardcoded or
//  inflated saving (issue #79: no fake stats). A value type with no SwiftUI or
//  RevenueCat dependency, so the math is unit-tested without any host / main-actor
//  deinit hazard — the view feeds it the live package prices.
//

import Foundation

struct PaywallPriceComparison: Equatable {
    let annualPrice: Decimal
    let monthlyPrice: Decimal

    /// The annual price spread evenly across twelve months.
    var monthlyEquivalent: Decimal {
        annualPrice / 12
    }

    /// How many months of the monthly plan the annual buyer effectively gets free —
    /// "pay for N, get 12" math against the real prices (issue #162's annual anchor).
    /// `nil` when there is no honest saving to show: non-positive prices, or an annual
    /// plan that costs a full year of monthly or more.
    var monthsFree: Int? {
        guard monthlyPrice > 0, annualPrice > 0 else { return nil }
        let annual = (annualPrice as NSDecimalNumber).doubleValue
        let monthly = (monthlyPrice as NSDecimalNumber).doubleValue
        let paidMonths = Int((annual / monthly).rounded())
        let free = 12 - paidMonths
        return free > 0 ? free : nil
    }

    /// The "$X/mo" string for the annual plan's monthly equivalent, formatted with the
    /// store-provided currency formatter so it matches the user's locale and currency.
    func monthlyEquivalentString(using formatter: NumberFormatter) -> String? {
        formatter.string(from: monthlyEquivalent as NSDecimalNumber)
    }
}
