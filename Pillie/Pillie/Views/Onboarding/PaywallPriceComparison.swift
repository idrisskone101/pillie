//
//  PaywallPriceComparison.swift
//  Pillie
//
//  Pure, testable derivation of the annual-vs-monthly comparison shown on the
//  paywall. Both the "$X/mo" equivalent and the "Save N%" badge are computed from the
//  real StoreKit / RevenueCat prices, so the paywall never shows a hardcoded or
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

    /// Whole-number percent saved by paying annually instead of monthly, or `nil` when
    /// there is no honest saving to show — non-positive prices, or an annual plan that
    /// is not actually cheaper per month.
    var savingsPercent: Int? {
        guard monthlyPrice > 0, annualPrice > 0 else { return nil }
        let monthly = (monthlyPrice as NSDecimalNumber).doubleValue
        let perMonth = (monthlyEquivalent as NSDecimalNumber).doubleValue
        let percent = Int(((1 - perMonth / monthly) * 100).rounded())
        return percent > 0 ? percent : nil
    }

    /// The "$X/mo" string for the annual plan's monthly equivalent, formatted with the
    /// store-provided currency formatter so it matches the user's locale and currency.
    func monthlyEquivalentString(using formatter: NumberFormatter) -> String? {
        formatter.string(from: monthlyEquivalent as NSDecimalNumber)
    }
}
