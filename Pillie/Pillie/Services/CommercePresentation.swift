import Foundation
import RevenueCat

enum PilliePlusPlan: String, CaseIterable, Equatable {
    case annual
    case monthly
    case lifetime

    var productID: String {
        switch self {
        case .annual: SubscriptionManager.annualProductID
        case .monthly: SubscriptionManager.monthlyProductID
        case .lifetime: SubscriptionManager.lifetimeProductID
        }
    }

    var analyticsPlan: AnalyticsPlan {
        switch self {
        case .annual: .annual
        case .monthly: .monthly
        case .lifetime: .lifetime
        }
    }
}

enum PilliePlusPackageResolver {
    static func resolve<Package>(
        plan: PilliePlusPlan,
        preferredPackage: Package?,
        availablePackages: [Package],
        productIdentifier: KeyPath<Package, String>
    ) -> Package? {
        preferredPackage ?? availablePackages.first {
            $0[keyPath: productIdentifier] == plan.productID
        }
    }
}

enum CommercePresentation {
    enum PeriodUnit {
        case day
        case week
        case month
        case year
    }

    static func priceAndPeriod(
        displayPrice: String,
        periodValue: Int,
        periodUnit: PeriodUnit,
        locale: Locale = .current
    ) -> String {
        let key = periodValue == 1
            ? "paywall.plan.price_period"
            : "paywall.plan.price_period_multiple"
        return PillieLocalization.formatted(
            key,
            table: "Commerce",
            locale: locale,
            arguments: displayPrice,
            periodText(
                value: periodValue,
                unit: periodUnit,
                locale: locale
            )
        )
    }

    static func priceAndPeriod(
        displayPrice: String,
        subscriptionPeriod: SubscriptionPeriod?,
        locale: Locale = .current
    ) -> String {
        guard let subscriptionPeriod else { return displayPrice }
        let unit: PeriodUnit = switch subscriptionPeriod.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .month
        }
        return priceAndPeriod(
            displayPrice: displayPrice,
            periodValue: subscriptionPeriod.value,
            periodUnit: unit,
            locale: locale
        )
    }

    static func trialEndText(
        date: Date,
        locale: Locale = .current
    ) -> String {
        let dateText = date.formatted(
            Date.FormatStyle()
                .day()
                .month(.wide)
                .year()
                .locale(locale)
        )
        return PillieLocalization.formatted(
            "trial.status.ends",
            table: "Commerce",
            locale: locale,
            arguments: dateText
        )
    }

    static func trialEndSuccessSubtitle(
        cohort: TrialEndPaywallCohort,
        locale: Locale = .current
    ) -> String {
        let key = switch cohort {
        case .blockerConfigured: "trial.end.success.blocking"
        case .reminderOnly: "trial.end.success.reminder_only"
        }
        return PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    static func comparisonTierLabel(
        freeIncluded: Bool,
        plusIncluded: Bool,
        locale: Locale = .current
    ) -> String {
        let key = switch (freeIncluded, plusIncluded) {
        case (true, true): "paywall.accessibility.tier.both"
        case (false, true): "paywall.accessibility.tier.plus_only"
        case (true, false): "paywall.accessibility.tier.free_only"
        case (false, false): "paywall.accessibility.tier.neither"
        }
        return PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    static func purchaseErrorMessage(
        _ error: Error,
        locale: Locale = .current
    ) -> String {
        if let purchaseError = error as? SubscriptionPurchaseError,
           purchaseError == .missingPlusEntitlement {
            return PillieLocalization.string(
                "paywall.purchase_error.missing_entitlement",
                table: "Commerce",
                locale: locale
            )
        }
        return genericErrorMessage(locale: locale)
    }

    static func restoreErrorMessage(
        _ error: Error,
        locale: Locale = .current
    ) -> String {
        genericErrorMessage(locale: locale)
    }

    private static func genericErrorMessage(locale: Locale) -> String {
        PillieLocalization.string(
            "paywall.error.generic_body",
            table: "Commerce",
            locale: locale
        )
    }

    /// Semantic feature-to-symbol order for the four gain-framed trial-end perks.
    /// The UI pairs these with localized titles by position and never compares copy.
    static let trialEndPerkSymbols = [
        "nosign",
        "iphone.radiowaves.left.and.right",
        "bell.badge",
        "text.bubble",
    ]

    private static func periodText(
        value: Int,
        unit: PeriodUnit,
        locale: Locale
    ) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = switch unit {
        case .day: [.day]
        case .week: [.weekOfMonth]
        case .month: [.month]
        case .year: [.year]
        }
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        let components = switch unit {
        case .day: DateComponents(day: value)
        case .week: DateComponents(weekOfMonth: value)
        case .month: DateComponents(month: value)
        case .year: DateComponents(year: value)
        }
        let formatted = formatter.string(from: components) ?? "\(value)"
        guard value == 1 else { return formatted }

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        let one = numberFormatter.string(from: 1) ?? "1"
        let prefix = "\(one) "
        return formatted.hasPrefix(prefix)
            ? String(formatted.dropFirst(prefix.count))
            : formatted
    }
}
