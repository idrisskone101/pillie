import Foundation

enum HistoryPresentation {
    enum DayStatus {
        case completed
        case unlogged
        case breakDay
    }

    struct MonthSummary: Equatable {
        let title: String
        let month: String
        let completedCount: String
        let completedBody: String
        let percentage: String
    }

    static func monthSummary(
        completed: Int,
        percentage: Int,
        displayedMonth: Date,
        locale: Locale = .current
    ) -> MonthSummary {
        MonthSummary(
            title: PillieLocalization.string("history.month.title", locale: locale),
            month: displayedMonth.formatted(
                Date.FormatStyle()
                    .month(.wide)
                    .year()
                    .locale(locale)
            ),
            completedCount: PillieLocalization.formatted(
                completed == 1
                    ? "history.month.checkin.single"
                    : "history.month.checkins",
                locale: locale,
                arguments: Int64(completed)
            ),
            completedBody: PillieLocalization.string(
                "history.month.checkins_body",
                locale: locale
            ),
            percentage: PillieLocalization.formatted(
                "history.month.on_track",
                locale: locale,
                arguments: Int64(percentage)
            )
        )
    }

    static func dayAccessibilityLabel(
        date: Date,
        status: DayStatus,
        locale: Locale = .current
    ) -> String {
        let statusKey = switch status {
        case .completed: "history.legend.completed"
        case .unlogged: "history.legend.unlogged"
        case .breakDay: "history.legend.break"
        }
        let dateText = date.formatted(
            Date.FormatStyle()
                .day()
                .month(.wide)
                .year()
                .locale(locale)
        )
        return PillieLocalization.formatted(
            "history.accessibility.day",
            locale: locale,
            arguments: dateText,
            PillieLocalization.string(statusKey, locale: locale)
        )
    }

    static func doseSubtitle(
        reminderHour: Int,
        reminderMinute: Int,
        method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> String {
        let timeKey: String
        switch reminderHour {
        case 5..<12:
            timeKey = "history.dayCorrection.subtitle.morning"
        case 12..<17:
            timeKey = "history.dayCorrection.subtitle.afternoon"
        default:
            timeKey = "history.dayCorrection.subtitle.evening"
        }

        let methodNoun = PillieLocalization.string(
            "history.dayCorrection.method.\(method.rawValue)",
            locale: locale
        )
        let timeText = reminderTimeText(hour: reminderHour, minute: reminderMinute, locale: locale)
        return PillieLocalization.formatted(timeKey, locale: locale, arguments: methodNoun, timeText)
    }

    private static func reminderTimeText(hour: Int, minute: Int, locale: Locale) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute(.twoDigits)
                .locale(locale)
        )
    }
}
