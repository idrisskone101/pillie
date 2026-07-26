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
                "history.month.checkins",
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
}
