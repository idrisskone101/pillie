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

    static func blockingSnoozeInterval(
        minutes: Int,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.formatted(
            "settings.blocking.snooze_value",
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

    static func blockingToggleStatus(
        isEnabled: Bool,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.string(
            isEnabled ? "global.status.on" : "global.status.off",
            locale: locale
        )
    }

    static func reminderMessagesSummary(
        hasCustom: Bool,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.string(
            hasCustom
                ? "settings.custom_messages.status.customized"
                : "settings.custom_messages.status.default",
            locale: locale
        )
    }

    static func supplyReminderTitle(
        method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> String {
        let key = switch method {
        case .pill: "today.refill.title"
        case .patch: "today.refill.title.patch"
        case .ring: "today.refill.title.ring"
        }
        return PillieLocalization.string(key, locale: locale)
    }
}

struct ProtocolEditorPresentation: Equatable {
    let customDayLabels: [String]
    let scheduleTitle: String
    let scheduleLines: [String]

    static func localized(
        method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> ProtocolEditorPresentation {
        let customDayLabels = [
            PillieLocalization.string("onboarding.regimen.active_days", locale: locale),
            PillieLocalization.string("onboarding.regimen.break_days", locale: locale),
        ]

        switch method {
        case .pill:
            return ProtocolEditorPresentation(
                customDayLabels: customDayLabels,
                scheduleTitle: PillieLocalization.string("settings.schedule.title", locale: locale),
                scheduleLines: []
            )
        case .patch:
            return ProtocolEditorPresentation(
                customDayLabels: customDayLabels,
                scheduleTitle: PillieLocalization.string("onboarding.fixed.patch.title", locale: locale),
                scheduleLines: [
                    PillieLocalization.string("onboarding.fixed.patch.day1", locale: locale),
                    PillieLocalization.string("onboarding.fixed.patch.day8", locale: locale),
                    PillieLocalization.string("onboarding.fixed.patch.day22", locale: locale),
                    PillieLocalization.string("onboarding.fixed.patch.break", locale: locale),
                ]
            )
        case .ring:
            return ProtocolEditorPresentation(
                customDayLabels: customDayLabels,
                scheduleTitle: PillieLocalization.string("onboarding.fixed.ring.title", locale: locale),
                scheduleLines: [
                    PillieLocalization.string("onboarding.fixed.ring.day1", locale: locale),
                    PillieLocalization.string("onboarding.fixed.ring.day2", locale: locale),
                    PillieLocalization.string("onboarding.fixed.ring.day22", locale: locale),
                    PillieLocalization.string("onboarding.fixed.ring.break", locale: locale),
                ]
            )
        }
    }
}

struct CustomReminderEditorContent: Equatable {
    let titleFieldLabel: String
    let messageFieldLabel: String
    let defaultTitlePlaceholder: String
    let defaultMessagePlaceholder: String
    private let selectedValue: String
    private let notSelectedValue: String

    func selectionValue(isSelected: Bool) -> String {
        isSelected ? selectedValue : notSelectedValue
    }

    static func localized(locale: Locale = .current) -> CustomReminderEditorContent {
        CustomReminderEditorContent(
            titleFieldLabel: PillieLocalization.string(
                "settings.custom_messages.field.title",
                locale: locale
            ),
            messageFieldLabel: PillieLocalization.string(
                "settings.custom_messages.field.message",
                locale: locale
            ),
            defaultTitlePlaceholder: PillieLocalization.string(
                "settings.custom_messages.placeholder.title",
                locale: locale
            ),
            defaultMessagePlaceholder: PillieLocalization.string(
                "settings.custom_messages.placeholder.message",
                locale: locale
            ),
            selectedValue: PillieLocalization.string(
                "accessibility.selection.selected",
                locale: locale
            ),
            notSelectedValue: PillieLocalization.string(
                "accessibility.selection.not_selected",
                locale: locale
            )
        )
    }
}
