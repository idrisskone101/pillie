//
//  PaywallCheckoutBuilderTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PaywallCheckoutBuilderTests {
    private let english = Locale(identifier: "en_US")

    private var offerings: PaywallOfferingsSnapshot {
        .fixture(
            annualDisplay: "$39.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: "$89.99",
            annual: 39.99,
            monthly: 4.99,
            lifetime: 89.99
        )
    }

    @Test func `Year keep CTA interpolates live annual price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            recurrence: .year,
            locale: english
        )
        #expect(checkout.primaryCTA == "Keep Pillie Plus · $39.99 billed yearly")
        #expect(checkout.isPurchaseEnabled)
    }

    @Test func `Month keep CTA interpolates live monthly price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            recurrence: .month,
            locale: english
        )
        #expect(checkout.primaryCTA.contains("$4.99"))
    }

    @Test func `Year get CTA interpolates live annual price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: offerings,
            recurrence: .year,
            locale: english
        )
        #expect(checkout.primaryCTA.contains("$39.99"))
    }

    @Test func `Month get CTA interpolates live monthly price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: offerings,
            recurrence: .month,
            locale: english
        )
        #expect(checkout.primaryCTA.contains("$4.99"))
    }

    @Test func `SAVE badge percent matches PaywallPriceComparison`() {
        let comparison = PaywallPriceComparison(
            annualPrice: offerings.annualPrice,
            monthlyPrice: offerings.monthlyPrice
        )
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            recurrence: .year,
            locale: english
        )
        #expect(checkout.yearTile.savingsBadge?.percent == comparison.savingsPercent)
    }

    @Test func `Lifetime link absent when snapshot has no lifetime price`() {
        let noLifetime = PaywallOfferingsSnapshot.fixture(
            annualDisplay: "$39.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: nil,
            annual: 39.99,
            monthly: 4.99,
            lifetime: nil
        )
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: noLifetime,
            recurrence: .year,
            locale: english
        )
        #expect(checkout.lifetimeLink == nil)
    }

    @Test func `Placeholder offerings disable purchase`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: nil,
            recurrence: .year,
            locale: english
        )
        #expect(!checkout.isPurchaseEnabled)
        #expect(checkout.primaryCTA.isEmpty)
    }

    @Test func `Purchase intent maps recurrence to Pillie Plus plan`() {
        #expect(PaywallPurchaseIntent.subscribe(.year).pilliePlusPlan == .annual)
        #expect(PaywallPurchaseIntent.subscribe(.month).pilliePlusPlan == .monthly)
        #expect(PaywallPurchaseIntent.lifetime.pilliePlusPlan == .lifetime)
    }
}
