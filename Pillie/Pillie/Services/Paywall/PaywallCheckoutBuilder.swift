//
//  PaywallCheckoutBuilder.swift
//  Pillie
//

import Foundation

enum PaywallCheckoutBuilder {
    static func build(
        verb: PaywallCTAVerb,
        offerings: PaywallOfferingsSnapshot?,
        recurrence: PaywallRecurrence,
        locale: Locale
    ) -> PaywallCheckoutSheet {
        guard let offerings else {
            return placeholder(recurrence: recurrence, locale: locale)
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

        let yearPrimaryLine = PillieLocalization.formatted(
            "paywall.stack.year.primary_line",
            table: "Commerce",
            locale: locale,
            arguments: monthlyEquivalentDisplay ?? "-",
            offerings.annualDisplay
        )

        let savingsBadge = comparison.savingsPercent.map { percent in
            PaywallSavingsBadge(
                percent: percent,
                label: PillieLocalization.formatted(
                    "paywall.stack.save_badge",
                    table: "Commerce",
                    locale: locale,
                    arguments: Int64(percent)
                )
            )
        }

        let yearTile = PaywallStackTile(
            title: PillieLocalization.string(
                "paywall.stack.year.title",
                table: "Commerce",
                locale: locale
            ),
            primaryLine: yearPrimaryLine,
            trailingPrice: nil,
            savingsBadge: savingsBadge,
            isSelected: recurrence == .year,
            accessibilityLabel: [
                PillieLocalization.string(
                    "paywall.stack.year.title",
                    table: "Commerce",
                    locale: locale
                ),
                yearPrimaryLine,
                savingsBadge?.label
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        )

        let monthCancelLine = PillieLocalization.string(
            "paywall.stack.month.primary_line",
            table: "Commerce",
            locale: locale
        )

        let monthTile = PaywallStackTile(
            title: PillieLocalization.string(
                "paywall.stack.month.title",
                table: "Commerce",
                locale: locale
            ),
            primaryLine: monthCancelLine,
            trailingPrice: offerings.monthlyDisplay,
            savingsBadge: nil,
            isSelected: recurrence == .month,
            accessibilityLabel: [
                PillieLocalization.string(
                    "paywall.stack.month.title",
                    table: "Commerce",
                    locale: locale
                ),
                monthCancelLine,
                offerings.monthlyDisplay
            ]
            .joined(separator: ", ")
        )

        let lifetimeLink = offerings.lifetimeDisplay.map { display in
            let text = PillieLocalization.formatted(
                "paywall.stack.lifetime_link",
                table: "Commerce",
                locale: locale,
                arguments: display
            )
            return PaywallLifetimeLink(text: text, accessibilityLabel: text)
        }

        let priceDisplay = recurrence == .year
            ? offerings.annualDisplay
            : offerings.monthlyDisplay

        let ctaKey = ctaKey(verb: verb, recurrence: recurrence)
        let primaryCTA = PillieLocalization.formatted(
            ctaKey,
            table: "Commerce",
            locale: locale,
            arguments: priceDisplay
        )

        let footer = PaywallFooter(
            reassurance: PillieLocalization.string(
                "paywall.stack.footer.reassurance",
                table: "Commerce",
                locale: locale
            ),
            restoreActionLabel: PillieLocalization.string(
                "paywall.action.restore",
                table: "Commerce",
                locale: locale
            )
        )

        return PaywallCheckoutSheet(
            selectedRecurrence: recurrence,
            yearTile: yearTile,
            monthTile: monthTile,
            lifetimeLink: lifetimeLink,
            primaryCTA: primaryCTA,
            isPurchaseEnabled: true,
            footer: footer
        )
    }

    private static func placeholder(
        recurrence: PaywallRecurrence,
        locale: Locale
    ) -> PaywallCheckoutSheet {
        let dash = "-"
        let yearTile = PaywallStackTile(
            title: PillieLocalization.string(
                "paywall.stack.year.title",
                table: "Commerce",
                locale: locale
            ),
            primaryLine: dash,
            trailingPrice: nil,
            savingsBadge: nil,
            isSelected: recurrence == .year,
            accessibilityLabel: dash
        )
        let monthTile = PaywallStackTile(
            title: PillieLocalization.string(
                "paywall.stack.month.title",
                table: "Commerce",
                locale: locale
            ),
            primaryLine: PillieLocalization.string(
                "paywall.stack.month.primary_line",
                table: "Commerce",
                locale: locale
            ),
            trailingPrice: dash,
            savingsBadge: nil,
            isSelected: recurrence == .month,
            accessibilityLabel: dash
        )
        return PaywallCheckoutSheet(
            selectedRecurrence: recurrence,
            yearTile: yearTile,
            monthTile: monthTile,
            lifetimeLink: nil,
            primaryCTA: "",
            isPurchaseEnabled: false,
            footer: PaywallFooter(
                reassurance: PillieLocalization.string(
                    "paywall.stack.footer.reassurance",
                    table: "Commerce",
                    locale: locale
                ),
                restoreActionLabel: PillieLocalization.string(
                    "paywall.action.restore",
                    table: "Commerce",
                    locale: locale
                )
            )
        )
    }

    private static func ctaKey(
        verb: PaywallCTAVerb,
        recurrence: PaywallRecurrence
    ) -> String {
        switch (verb, recurrence) {
        case (.keep, .year): "paywall.cta.keep_plus.billed_yearly"
        case (.keep, .month): "paywall.cta.keep_plus.billed_monthly"
        case (.get, .year): "paywall.cta.get_plus.billed_yearly"
        case (.get, .month): "paywall.cta.get_plus.billed_monthly"
        }
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
            "paywall.stack.monthly_equivalent",
            table: "Commerce",
            locale: locale,
            arguments: value
        )
    }
}
