//
//  PaywallPriceComparisonTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class PaywallPriceComparisonTests: XCTestCase {
    func testMonthlyEquivalentIsTheAnnualPriceSpreadAcrossTwelveMonths() {
        let comparison = PaywallPriceComparison(annualPrice: 49.99, monthlyPrice: 9.99)
        // 49.99 / 12 = 4.16583...
        XCTAssertEqual(
            (comparison.monthlyEquivalent as NSDecimalNumber).doubleValue,
            4.1658,
            accuracy: 0.0005
        )
    }

    func testSavingsPercentIsDerivedFromRealPricesNotHardcoded() {
        // Annual spread over 12 months ($4.17/mo) vs paying $9.99/mo is ~58% cheaper —
        // the same number the design mocks up, but computed from the live prices.
        let comparison = PaywallPriceComparison(annualPrice: 49.99, monthlyPrice: 9.99)
        XCTAssertEqual(comparison.savingsPercent, 58)
    }

    func testSavingsPercentTracksWhateverPricesTheStoreReturns() {
        // A different real price pair yields a different, still-truthful saving.
        // 59.99 / 12 = 5.00 ; 1 - (5.00 / 7.99) = 0.374 -> 37%
        let comparison = PaywallPriceComparison(annualPrice: 59.99, monthlyPrice: 7.99)
        XCTAssertEqual(comparison.savingsPercent, 37)
    }

    func testSavingsPercentIsNilWhenThereIsNoTruthfulSavingToClaim() {
        // An annual plan that is not actually cheaper per month must never invent a badge.
        let noSaving = PaywallPriceComparison(annualPrice: 120, monthlyPrice: 9.99)
        XCTAssertNil(noSaving.savingsPercent)

        // Degenerate / missing monthly price cannot produce a percentage.
        let zeroMonthly = PaywallPriceComparison(annualPrice: 49.99, monthlyPrice: 0)
        XCTAssertNil(zeroMonthly.savingsPercent)
    }

    func testMonthlyEquivalentStringUsesTheProvidedCurrencyFormatter() {
        let comparison = PaywallPriceComparison(annualPrice: 49.99, monthlyPrice: 9.99)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(comparison.monthlyEquivalentString(using: formatter), "$4.17")
    }
}
