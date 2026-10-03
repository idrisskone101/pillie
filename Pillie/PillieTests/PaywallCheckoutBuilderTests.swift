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

    private var noLifetime: PaywallOfferingsSnapshot {
        .fixture(
            annualDisplay: "$39.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: nil,
            annual: 39.99,
            monthly: 4.99,
            lifetime: nil
        )
    }

    @Test func `Year get CTA interpolates live annual price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: offerings,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.primaryCTA == "Get Pillie Plus · $39.99 billed yearly")
    }

    @Test func `Month get CTA interpolates live monthly price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: offerings,
            selection: .subscribe(.month),
            locale: english
        )
        #expect(checkout.primaryCTA == "Get Pillie Plus · $4.99 billed monthly")
    }

    @Test func `SAVE badge percent matches PaywallPriceComparison`() {
        let comparison = PaywallPriceComparison(
            annualPrice: offerings.annualPrice,
            monthlyPrice: offerings.monthlyPrice
        )
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.tiles[0].savingsBadge?.percent == comparison.savingsPercent)
    }

    @Test func `Stack lists Year, Month, Lifetime when offerings expose a lifetime price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.tiles.map(\.intent) == [.subscribe(.year), .subscribe(.month), .lifetime])
        #expect(checkout.tiles.map(\.title) == ["Year", "Month", "Lifetime"])
        let lifetime = checkout.tiles[2]
        #expect(lifetime.primaryLine == "Pay once, keep Plus for good")
        #expect(lifetime.trailingPrice == "$89.99")
        #expect(lifetime.savingsBadge == nil)
    }

    @Test func `Stack drops the Lifetime tile when offerings have no lifetime price`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: noLifetime,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.tiles.map(\.intent) == [.subscribe(.year), .subscribe(.month)])
    }

    @Test func `Lifetime selection falls back to Year when lifetime is not offered`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: noLifetime,
            selection: .lifetime,
            locale: english
        )
        #expect(checkout.selectedIntent == .subscribe(.year))
        #expect(checkout.tiles.filter(\.isSelected).map(\.intent) == [.subscribe(.year)])
        #expect(checkout.primaryCTA == "Keep Pillie Plus · $39.99 billed yearly")
        #expect(checkout.footer.reassurance == "Cancel anytime")
    }

    @Test(arguments: [
        (PaywallPurchaseIntent.subscribe(.year), "Keep Pillie Plus · $39.99 billed yearly", "Cancel anytime"),
        (.subscribe(.month), "Keep Pillie Plus · $4.99 billed monthly", "Cancel anytime"),
        (.lifetime, "Keep Pillie Plus · $89.99 once", "One payment. No renewal.")
    ])
    func `Selected intent drives the selected tile, CTA, and reassurance`(
        selection: PaywallPurchaseIntent,
        cta: String,
        reassurance: String
    ) {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .keep,
            offerings: offerings,
            selection: selection,
            locale: english
        )
        #expect(checkout.selectedIntent == selection)
        #expect(checkout.tiles.filter(\.isSelected).map(\.intent) == [selection])
        #expect(checkout.primaryCTA == cta)
        #expect(checkout.footer.reassurance == reassurance)
        #expect(checkout.footer.restoreActionLabel == "Restore purchases")
    }

    @Test func `Lifetime get CTA says once`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: offerings,
            selection: .lifetime,
            locale: english
        )
        #expect(checkout.primaryCTA == "Get Pillie Plus · $89.99 once")
    }

    @Test func `Placeholder offerings disable purchase`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: nil,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(!checkout.isPurchaseEnabled)
        #expect(checkout.primaryCTA.isEmpty)
    }

    @Test func `Placeholder falls back from Lifetime to Year`() {
        let checkout = PaywallCheckoutBuilder.build(
            verb: .get,
            offerings: nil,
            selection: .lifetime,
            locale: english
        )
        #expect(checkout.selectedIntent == .subscribe(.year))
        #expect(checkout.tiles.filter(\.isSelected).map(\.intent) == [.subscribe(.year)])
        #expect(checkout.footer.reassurance == "Cancel anytime")
    }

    @Test func `Purchase intent maps recurrence to Pillie Plus plan`() {
        #expect(PaywallPurchaseIntent.subscribe(.year).pilliePlusPlan == .annual)
        #expect(PaywallPurchaseIntent.subscribe(.month).pilliePlusPlan == .monthly)
        #expect(PaywallPurchaseIntent.lifetime.pilliePlusPlan == .lifetime)
    }
}
