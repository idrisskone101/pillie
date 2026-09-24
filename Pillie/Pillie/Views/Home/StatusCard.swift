//
//  StatusCard.swift
//  Pillie
//

import SwiftUI

struct StatusCard: View {
    @Environment(PillStore.self) var store
    @Environment(\.locale) private var locale
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)

    var body: some View {
        let isTodayTaken = store.isTodayTaken
        let isTodayPassiveOrBreak = store.isTodayPassiveOrBreak
        let alarmAction = store.alarmAction
        let todayAction = store.dueAction(on: store.today)
        let reminderTime = SettingsPresentation.time(
            hour: store.reminderHour,
            minute: store.reminderMinute,
            locale: locale
        )
        let iconName = iconName(for: isTodayPassiveOrBreak ? todayAction : alarmAction, isTodayTaken: isTodayTaken)
        let actionTitle = actionTitle(
            for: alarmAction,
            todayAction: todayAction,
            isTodayTaken: isTodayTaken,
            isTodayPassiveOrBreak: isTodayPassiveOrBreak,
            reminderTime: reminderTime
        )
        statusMainContent(
            iconName: iconName,
            reminderTime: reminderTime,
            actionTitle: actionTitle,
            isTodayTaken: isTodayTaken
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isTodayTaken ? PillieTheme.coralLight : PillieTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(isTodayTaken ? PillieTheme.coralFaded : PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .animation(valueChangeAnimation, value: isTodayTaken)
    }

    private func statusMainContent(
        iconName: String,
        reminderTime: String,
        actionTitle: String,
        isTodayTaken: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(isTodayTaken ? PillieTheme.coral : PillieTheme.lavender)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .contentTransition(.opacity)
                        .animation(valueChangeAnimation, value: iconName)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(reminderTime)
                    .font(.pillie(28, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: reminderTime)

                Text(actionTitle)
                    .font(.pillieBody())
                    .foregroundStyle(isTodayTaken ? PillieTheme.textPrimary : PillieTheme.textMuted)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                    .layoutPriority(1)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: actionTitle)
            }
        }
    }

    private func iconName(for alarmAction: DoseScheduleAction?, isTodayTaken: Bool) -> String {
        if isTodayTaken {
            return "checkmark"
        }

        let method = alarmAction?.method ?? store.pack.method
        switch method {
        case .pill:
            return "pills.fill"
        case .patch:
            return "square.fill.on.square.fill"
        case .ring:
            return "circle.grid.cross"
        }
    }

    private func actionTitle(
        for alarmAction: DoseScheduleAction?,
        todayAction: DoseScheduleAction?,
        isTodayTaken: Bool,
        isTodayPassiveOrBreak: Bool,
        reminderTime: String
    ) -> String {
        if isTodayPassiveOrBreak && !isTodayTaken {
            if let alarmAction, !Calendar.current.isDate(alarmAction.date, inSameDayAs: store.today) {
                return nextDoseTitle(for: alarmAction, reminderTime: reminderTime)
            }
            return PillieLocalization.string("today.empty.title", locale: locale)
        }

        guard let alarmAction else {
            return PillieLocalization.string("today.empty.title", locale: locale)
        }
        guard isTodayTaken else {
            return DueActionCopy.localizedLabel(for: alarmAction, locale: locale)
        }

        let calendar = Calendar.current
        if calendar.isDate(alarmAction.date, inSameDayAs: store.today) {
            return PillieLocalization.string("global.status.completed", locale: locale)
        }
        return nextDoseTitle(for: alarmAction, reminderTime: reminderTime)
    }

    private func nextDoseTitle(for alarmAction: DoseScheduleAction, reminderTime: String) -> String {
        let weekday = alarmAction.date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .locale(locale)
        )
        switch NextDoseDayPhrase.resolve(today: store.today, next: alarmAction.date) {
        case .tomorrow:
            return PillieLocalization.formatted(
                "today.next_action.tomorrow",
                locale: locale,
                arguments: reminderTime
            )
        case .weekday:
            return PillieLocalization.formatted(
                "today.next_action.date",
                locale: locale,
                arguments: weekday, reminderTime
            )
        case .nextWeek:
            return PillieLocalization.formatted(
                "today.next_action.next_week",
                locale: locale,
                arguments: weekday, reminderTime
            )
        }
    }

}

enum NextDoseDayPhrase: Equatable {
    case tomorrow
    case weekday
    case nextWeek

    static func resolve(today: Date, next: Date, calendar: Calendar = .current) -> NextDoseDayPhrase {
        let start = calendar.startOfDay(for: today)
        let target = calendar.startOfDay(for: next)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        if days <= 1 {
            return .tomorrow
        }
        let sameWeek = calendar.component(.weekOfYear, from: start) == calendar.component(.weekOfYear, from: target)
            && calendar.component(.yearForWeekOfYear, from: start) == calendar.component(.yearForWeekOfYear, from: target)
        return sameWeek ? .weekday : .nextWeek
    }
}

#Preview {
    StatusCard()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
