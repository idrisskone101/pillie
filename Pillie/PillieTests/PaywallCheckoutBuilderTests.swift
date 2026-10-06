//
//  PaywallCheckoutBuilderTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PaywallCheckoutBuilderTests {
    private let english = Locale(identifier: "en")

    private var offerings: PaywallOfferingsSnapshot {
        .fixture(
            annualDisplay: "$29.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: "$69.99",
            annual: 29.99,
            monthly: 4.99,
            lifetime: 69.99
        )
    }

    private var noLifetime: PaywallOfferingsSnapshot {
        .fixture(
            annualDisplay: "$29.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: nil,
            annual: 29.99,
            monthly: 4.99,
            lifetime: nil
        )
    }

    @Test func `Cards list Month, Year, Lifetime with prices, captions, and the Year badge`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .settingsFree,
            offerings: offerings,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.cards == [
            PaywallPlanCard(
                intent: .subscribe(.month),
                title: "Month",
                price: "$4.99",
                caption: "per month",
                savingsBadge: nil,
                isSelected: false,
                accessibilityLabel: "Month, $4.99, per month"
            ),
            PaywallPlanCard(
                intent: .subscribe(.year),
                title: "Year",
                price: "$29.99",
                caption: "$2.50 a month",
                savingsBadge: "Save 50%",
                isSelected: true,
                accessibilityLabel: "Year, $29.99, $2.50 a month, Save 50%"
            ),
            PaywallPlanCard(
                intent: .lifetime,
                title: "Lifetime",
                price: "$69.99",
                caption: "pay once",
                savingsBadge: nil,
                isSelected: false,
                accessibilityLabel: "Lifetime, $69.99, pay once"
            ),
        ])
        #expect(checkout.isPurchaseEnabled)
    }

    @Test func `Year has no badge when the annual plan saves nothing`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .settingsFree,
            offerings: .fixture(
                annualDisplay: "$64.99",
                monthlyDisplay: "$4.99",
                lifetimeDisplay: nil,
                annual: 64.99,
                monthly: 4.99,
                lifetime: nil
            ),
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.cards.map(\.savingsBadge) == [nil, nil])
    }

    @Test func `Cards drop Lifetime when offerings have no lifetime price`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .settingsFree,
            offerings: noLifetime,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.cards.map(\.intent) == [.subscribe(.month), .subscribe(.year)])
    }

    @Test func `Lifetime selection falls back to Year when lifetime is not offered`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .duringTrial,
            offerings: noLifetime,
            selection: .lifetime,
            locale: english
        )
        #expect(checkout.selectedIntent == .subscribe(.year))
        #expect(checkout.cards.filter(\.isSelected).map(\.intent) == [.subscribe(.year)])
        #expect(checkout.primaryCTA == "Keep Plus for $29.99 a year")
    }

    @Test(arguments: [
        (HonestPaywallMoment.duringTrial, PaywallPurchaseIntent.subscribe(.year), "Keep Plus for $29.99 a year"),
        (.duringTrial, .subscribe(.month), "Keep Plus for $4.99 a month"),
        (.trialEnded(.hardPaywall), .lifetime, "Keep Plus for a one-time $69.99"),
        (.settingsFree, .subscribe(.year), "Get Plus for $29.99 a year"),
        (.settingsFree, .subscribe(.month), "Get Plus for $4.99 a month"),
        (.settingsFree, .lifetime, "Get Plus for a one-time $69.99"),
    ])
    func `CTA follows the moment's verb and the selected plan`(
        moment: HonestPaywallMoment,
        selection: PaywallPurchaseIntent,
        cta: String
    ) {
        let checkout = PaywallCheckoutBuilder.build(
            moment: moment,
            offerings: offerings,
            selection: selection,
            locale: english
        )
        #expect(checkout.selectedIntent == selection)
        #expect(checkout.cards.filter(\.isSelected).map(\.intent) == [selection])
        #expect(checkout.primaryCTA == cta)
    }

    @Test(arguments: [
        (HonestPaywallMoment.duringTrial, PaywallPurchaseIntent.subscribe(.year), "You’re charged today. Cancel anytime in Settings."),
        (.duringTrial, .subscribe(.month), "You’re charged today. Cancel anytime in Settings."),
        (.duringTrial, .lifetime, "One payment. No renewal."),
        (.settingsFree, .subscribe(.year), "Cancel anytime in Settings"),
        (.trialEnded(.hardPaywall), .subscribe(.month), "Cancel anytime in Settings"),
        (.trialEnded(.legacy), .lifetime, "One payment. No renewal."),
    ])
    func `Reassurance says when the charge lands`(
        moment: HonestPaywallMoment,
        selection: PaywallPurchaseIntent,
        reassurance: String
    ) {
        let checkout = PaywallCheckoutBuilder.build(
            moment: moment,
            offerings: offerings,
            selection: selection,
            locale: english
        )
        #expect(checkout.reassurance == reassurance)
    }

    @Test func `Placeholder shows Month and Year without prices and disables purchase`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .settingsFree,
            offerings: nil,
            selection: .subscribe(.year),
            locale: english
        )
        #expect(checkout.cards.map(\.intent) == [.subscribe(.month), .subscribe(.year)])
        #expect(checkout.cards.map(\.price) == ["-", "-"])
        #expect(checkout.cards.map(\.caption) == ["per month", "- a month"])
        #expect(checkout.cards.map(\.savingsBadge) == [nil, nil])
        #expect(!checkout.isPurchaseEnabled)
        #expect(checkout.primaryCTA == "")
        #expect(checkout.reassurance == "Cancel anytime in Settings")
    }

    @Test func `Placeholder falls back from Lifetime to Year`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .duringTrial,
            offerings: nil,
            selection: .lifetime,
            locale: english
        )
        #expect(checkout.selectedIntent == .subscribe(.year))
        #expect(checkout.cards.filter(\.isSelected).map(\.intent) == [.subscribe(.year)])
        #expect(checkout.reassurance == "You’re charged today. Cancel anytime in Settings.")
    }

    @Test func `Purchase intent maps recurrence to Pillie Plus plan`() {
        #expect(PaywallPurchaseIntent.subscribe(.year).pilliePlusPlan == .annual)
        #expect(PaywallPurchaseIntent.subscribe(.month).pilliePlusPlan == .monthly)
        #expect(PaywallPurchaseIntent.lifetime.pilliePlusPlan == .lifetime)
    }
}
