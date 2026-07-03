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

    func testMonthsFreeIsDerivedFromRealPricesNotHardcoded() {
        // Reverse Trial pricing (issue #162): $29.99/yr vs $4.99/mo — the annual price
        // buys ~6 months of monthly, so the honest anchor is "6 months free", computed
        // from the live prices rather than copied from a mock.
        let comparison = PaywallPriceComparison(annualPrice: 29.99, monthlyPrice: 4.99)
        XCTAssertEqual(comparison.monthsFree, 6)
    }

    func testMonthsFreeTracksWhateverPricesTheStoreReturns() {
        // The classic 10x-monthly annual yields the classic "2 months free".
        let comparison = PaywallPriceComparison(annualPrice: 49.90, monthlyPrice: 4.99)
        XCTAssertEqual(comparison.monthsFree, 2)
    }

    func testMonthsFreeIsNilWhenThereIsNoTruthfulSavingToClaim() {
        // An annual plan that costs a full year of monthly (or more) gives nothing free.
        XCTAssertNil(PaywallPriceComparison(annualPrice: 120, monthlyPrice: 9.99).monthsFree)

        // Degenerate / missing prices cannot produce a claim.
        XCTAssertNil(PaywallPriceComparison(annualPrice: 29.99, monthlyPrice: 0).monthsFree)
        XCTAssertNil(PaywallPriceComparison(annualPrice: 0, monthlyPrice: 4.99).monthsFree)
    }

    func testMonthlyEquivalentStringUsesTheProvidedCurrencyFormatter() {
        let comparison = PaywallPriceComparison(annualPrice: 49.99, monthlyPrice: 9.99)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(comparison.monthlyEquivalentString(using: formatter), "$4.17")
    }
}
