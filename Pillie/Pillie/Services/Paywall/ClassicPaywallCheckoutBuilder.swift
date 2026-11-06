//
//  ClassicPaywallCheckoutBuilder.swift
//  Pillie
//
//  Ported from PaywallCheckoutBuilder at 2c8062a. Keys that changed since
//  then live under `paywall.classic.`.
//

import Foundation

enum ClassicPaywallCheckoutBuilder {
    static func build(
        verb: PaywallCTAVerb,
        offerings: PaywallOfferingsSnapshot?,
        selection: PaywallPurchaseIntent,
        locale: Locale
    ) -> ClassicPaywallCheckout {
        guard let offerings else {
            return placeholder(selection: selection, locale: locale)
        }

        let comparison = PaywallPriceComparison(
            annualPrice: offerings.annualPrice,
            monthlyPrice: offerings.monthlyPrice
        )
        let monthlyEquivalentDisplay = monthlyEquivalentDisplay(
            comparison: comparison,
            currencyCode: offerings.currencyCode,
            locale: locale
        )
        let savingsBadge = comparison.savingsPercent.map { percent in
            ClassicPaywallSavingsBadge(
                percent: percent,
                label: PillieLocalization.formatted(
                    "paywall.stack.save_badge",
                    table: "Commerce",
                    locale: locale,
                    arguments: Int64(percent)
                )
            )
        }

        var offers: [ClassicTileContent] = [
            ClassicTileContent(
                intent: .subscribe(.year),
                title: commerce("paywall.stack.year.title", locale),
                primaryLine: PillieLocalization.formatted(
                    "paywall.classic.paywall.stack.year.primary_line",
                    table: "Commerce",
                    locale: locale,
                    arguments: monthlyEquivalentDisplay ?? "-",
                    offerings.annualDisplay
                ),
                trailingPrice: nil,
                savingsBadge: savingsBadge,
                ctaPrice: offerings.annualDisplay
            ),
            ClassicTileContent(
                intent: .subscribe(.month),
                title: commerce("paywall.stack.month.title", locale),
                primaryLine: commerce("paywall.classic.paywall.stack.month.primary_line", locale),
                trailingPrice: offerings.monthlyDisplay,
                savingsBadge: nil,
                ctaPrice: offerings.monthlyDisplay
            )
        ]
        if let lifetimeDisplay = offerings.lifetimeDisplay {
            offers.append(ClassicTileContent(
                intent: .lifetime,
                title: commerce("paywall.stack.lifetime.title", locale),
                primaryLine: commerce("paywall.classic.paywall.stack.lifetime.primary_line", locale),
                trailingPrice: lifetimeDisplay,
                savingsBadge: nil,
                ctaPrice: lifetimeDisplay
            ))
        }

        // A lifetime selection can outlive offerings that stop exposing it.
        let selected = offers.first { $0.intent == selection } ?? offers[0]

        return ClassicPaywallCheckout(
            selectedIntent: selected.intent,
            tiles: offers.map { $0.tile(isSelected: $0.intent == selected.intent) },
            primaryCTA: PillieLocalization.formatted(
                ctaKey(verb: verb, intent: selected.intent),
                table: "Commerce",
                locale: locale,
                arguments: selected.ctaPrice
            ),
            isPurchaseEnabled: true,
            footer: footer(for: selected.intent, locale: locale)
        )
    }

    private static func placeholder(
        selection: PaywallPurchaseIntent,
        locale: Locale
    ) -> ClassicPaywallCheckout {
        let dash = "-"
        let offers = [
            ClassicTileContent(
                intent: .subscribe(.year),
                title: commerce("paywall.stack.year.title", locale),
                primaryLine: dash,
                trailingPrice: nil,
                savingsBadge: nil,
                ctaPrice: dash,
                accessibilityLabel: dash
            ),
            ClassicTileContent(
                intent: .subscribe(.month),
                title: commerce("paywall.stack.month.title", locale),
                primaryLine: commerce("paywall.classic.paywall.stack.month.primary_line", locale),
                trailingPrice: dash,
                savingsBadge: nil,
                ctaPrice: dash,
                accessibilityLabel: dash
            )
        ]
        let selected = offers.first { $0.intent == selection }?.intent ?? .subscribe(.year)
        return ClassicPaywallCheckout(
            selectedIntent: selected,
            tiles: offers.map { $0.tile(isSelected: $0.intent == selected) },
            primaryCTA: "",
            isPurchaseEnabled: false,
            footer: footer(for: selected, locale: locale)
        )
    }

    private static func footer(
        for intent: PaywallPurchaseIntent,
        locale: Locale
    ) -> ClassicPaywallFooter {
        let reassuranceKey = switch intent {
        case .subscribe: "paywall.classic.paywall.stack.footer.cancel_anytime"
        case .lifetime: "paywall.stack.footer.one_payment"
        }
        return ClassicPaywallFooter(
            reassurance: commerce(reassuranceKey, locale),
            restoreActionLabel: commerce("paywall.action.restore", locale)
        )
    }

    private static func ctaKey(
        verb: PaywallCTAVerb,
        intent: PaywallPurchaseIntent
    ) -> String {
        switch (verb, intent) {
        case (.keep, .subscribe(.year)): "paywall.classic.paywall.cta.keep_plus.billed_yearly"
        case (.keep, .subscribe(.month)): "paywall.classic.paywall.cta.keep_plus.billed_monthly"
        case (.keep, .lifetime): "paywall.classic.paywall.cta.keep_plus.once"
        case (.get, .subscribe(.year)): "paywall.classic.paywall.cta.get_plus.billed_yearly"
        case (.get, .subscribe(.month)): "paywall.classic.paywall.cta.get_plus.billed_monthly"
        case (.get, .lifetime): "paywall.classic.paywall.cta.get_plus.once"
        }
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
        guard let value = comparison.monthlyEquivalentString(using: formatter) else {
            return nil
        }
        return PillieLocalization.formatted(
            "paywall.classic.paywall.stack.monthly_equivalent",
            table: "Commerce",
            locale: locale,
            arguments: value
        )
    }
}

private struct ClassicTileContent {
    let intent: PaywallPurchaseIntent
    let title: String
    let primaryLine: String
    let trailingPrice: String?
    let savingsBadge: ClassicPaywallSavingsBadge?
    let ctaPrice: String
    var accessibilityLabel: String?

    func tile(isSelected: Bool) -> ClassicPaywallStackTile {
        ClassicPaywallStackTile(
            intent: intent,
            title: title,
            primaryLine: primaryLine,
            trailingPrice: trailingPrice,
            savingsBadge: savingsBadge,
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel
                ?? [title, primaryLine, savingsBadge?.label ?? trailingPrice]
                    .compactMap { $0 }
                    .joined(separator: ", ")
        )
    }
}
