import Foundation

enum SettingsPresentation {
    static func time(
        hour: Int,
        minute: Int,
        locale: Locale = .current
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let date = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute)
        ) ?? Date()
        return date.formatted(
            Date.FormatStyle().hour().minute().locale(locale)
        )
    }

    static func interval(
        minutes: Int,
        locale: Locale = .current
    ) -> String {
        if minutes == 1 {
            return PillieLocalization.string(
                "settings.followup.interval.single",
                locale: locale
            )
        }
        return PillieLocalization.formatted(
            "settings.followup.interval",
            locale: locale,
            arguments: Int64(minutes)
        )
    }

    static func cycleDay(
        day: Int,
        total: Int,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.formatted(
            "today.pack.day_of_total",
            locale: locale,
            arguments: Int64(day),
            Int64(total)
        )
    }
}
