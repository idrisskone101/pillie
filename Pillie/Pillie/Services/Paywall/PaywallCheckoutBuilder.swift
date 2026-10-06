//
//  PaywallCheckoutBuilder.swift
//  Pillie
//

import Foundation

enum PaywallCheckoutBuilder {
    static func build(
        moment: HonestPaywallMoment,
        offerings: PaywallOfferingsSnapshot?,
        selection: PaywallPurchaseIntent,
        locale: Locale
    ) -> PaywallCheckoutSheet {
        guard let offerings else {
            return placeholder(moment: moment, selection: selection, locale: locale)
        }

        let comparison = PaywallPriceComparison(
            annualPrice: offerings.annualPrice,
            monthlyPrice: offerings.monthlyPrice
        )
        let savingsBadge = comparison.savingsPercent.map { percent in
            PillieLocalization.formatted(
                "paywall.stack.save_badge",
                table: "Commerce",
                locale: locale,
                arguments: Int64(percent)
            )
        }

        var offers: [CardContent] = [
            CardContent(
                intent: .subscribe(.month),
                title: commerce("paywall.stack.month.title", locale),
                price: offerings.monthlyDisplay,
                caption: commerce("paywall.card.month.caption", locale),
                savingsBadge: nil
            ),
            CardContent(
                intent: .subscribe(.year),
                title: commerce("paywall.stack.year.title", locale),
                price: offerings.annualDisplay,
                caption: yearCaption(
                    monthlyEquivalent: monthlyEquivalentDisplay(
                        comparison: comparison,
                        currencyCode: offerings.currencyCode,
                        locale: locale
                    ),
                    locale: locale
                ),
                savingsBadge: savingsBadge
            ),
        ]
        if let lifetimeDisplay = offerings.lifetimeDisplay {
            offers.append(CardContent(
                intent: .lifetime,
                title: commerce("paywall.stack.lifetime.title", locale),
                price: lifetimeDisplay,
                caption: commerce("paywall.card.lifetime.caption", locale),
                savingsBadge: nil
            ))
        }

        // A lifetime selection can outlive offerings that stop exposing it.
        let selected = offers.first { $0.intent == selection }
            ?? offers.first { $0.intent == .subscribe(.year) }
            ?? offers[0]

        return PaywallCheckoutSheet(
            selectedIntent: selected.intent,
            cards: offers.map { $0.card(isSelected: $0.intent == selected.intent) },
            primaryCTA: PillieLocalization.formatted(
                ctaKey(verb: moment.ctaVerb, intent: selected.intent),
                table: "Commerce",
                locale: locale,
                arguments: selected.price
            ),
            isPurchaseEnabled: true,
            reassurance: reassurance(moment: moment, intent: selected.intent, locale: locale)
        )
    }

    private static func placeholder(
        moment: HonestPaywallMoment,
        selection: PaywallPurchaseIntent,
        locale: Locale
    ) -> PaywallCheckoutSheet {
        let dash = "-"
        let offers = [
            CardContent(
                intent: .subscribe(.month),
                title: commerce("paywall.stack.month.title", locale),
                price: dash,
                caption: commerce("paywall.card.month.caption", locale),
                savingsBadge: nil
            ),
            CardContent(
                intent: .subscribe(.year),
                title: commerce("paywall.stack.year.title", locale),
                price: dash,
                caption: yearCaption(monthlyEquivalent: nil, locale: locale),
                savingsBadge: nil
            ),
        ]
        let selected = offers.first { $0.intent == selection }?.intent ?? .subscribe(.year)
        return PaywallCheckoutSheet(
            selectedIntent: selected,
            cards: offers.map { $0.card(isSelected: $0.intent == selected) },
            primaryCTA: "",
            isPurchaseEnabled: false,
            reassurance: reassurance(moment: moment, intent: selected, locale: locale)
        )
    }

    private static func reassurance(
        moment: HonestPaywallMoment,
        intent: PaywallPurchaseIntent,
        locale: Locale
    ) -> String {
        let key = switch (moment, intent) {
        case (_, .lifetime): "paywall.stack.footer.one_payment"
        case (.duringTrial, .subscribe): "paywall.footer.charged_today"
        case (.trialEnded, .subscribe), (.settingsFree, .subscribe): "paywall.footer.cancel_anytime"
        }
        return commerce(key, locale)
    }

    private static func ctaKey(
        verb: PaywallCTAVerb,
        intent: PaywallPurchaseIntent
    ) -> String {
        switch (verb, intent) {
        case (.keep, .subscribe(.year)): "paywall.cta.keep_plus.billed_yearly"
        case (.keep, .subscribe(.month)): "paywall.cta.keep_plus.billed_monthly"
        case (.keep, .lifetime): "paywall.cta.keep_plus.once"
        case (.get, .subscribe(.year)): "paywall.cta.get_plus.billed_yearly"
        case (.get, .subscribe(.month)): "paywall.cta.get_plus.billed_monthly"
        case (.get, .lifetime): "paywall.cta.get_plus.once"
        }
    }

    private static func yearCaption(monthlyEquivalent: String?, locale: Locale) -> String {
        PillieLocalization.formatted(
            "paywall.card.year.caption",
            table: "Commerce",
            locale: locale,
            arguments: monthlyEquivalent ?? "-"
        )
    }

    private static func commerce(_ key: String, _ locale: Locale) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    private static func monthlyEquivalentDisplay(
        comparison: PaywallPriceComparison,
        currencyCode: String?,
        locale: Locale
    ) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        if let currencyCode {
            formatter.currencyCode = currencyCode
        }
        return comparison.monthlyEquivalentString(using: formatter)
    }
}

private struct CardContent {
    let intent: PaywallPurchaseIntent
    let title: String
    let price: String
    let caption: String
    let savingsBadge: String?

    func card(isSelected: Bool) -> PaywallPlanCard {
        PaywallPlanCard(
            intent: intent,
            title: title,
            price: price,
            caption: caption,
            savingsBadge: savingsBadge,
            isSelected: isSelected,
            accessibilityLabel: [title, price, caption, savingsBadge]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}
