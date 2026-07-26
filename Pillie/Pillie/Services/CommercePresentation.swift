import Foundation
import RevenueCat

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
        PillieLocalization.formatted(
            "paywall.plan.price_period",
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
