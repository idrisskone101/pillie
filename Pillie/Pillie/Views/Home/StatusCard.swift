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
        let badgeText = badgeText(
            alarmAction: alarmAction,
            todayAction: todayAction,
            isTodayTaken: isTodayTaken,
            isTodayPassiveOrBreak: isTodayPassiveOrBreak
        )

        HStack(spacing: 14) {
            // Alarm icon circle
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

            // Time + subtitle
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: actionTitle)
            }

            Spacer()

            // NEXT PILL badge
            HStack(spacing: 5) {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 6, height: 6)

                Text(badgeText)
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.coral)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: badgeText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isTodayTaken ? Color.white.opacity(0.8) : PillieTheme.coral.opacity(0.1))
            .clipShape(Capsule())
        }
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
            return PillieLocalization.string("today.empty.title", locale: locale)
        }

        guard let alarmAction else {
            return PillieLocalization.string("today.empty.title", locale: locale)
        }
        guard isTodayTaken else {
            return PillieLocalization.string("today.action.mark_complete", locale: locale)
        }

        let calendar = Calendar.current
        if calendar.isDate(alarmAction.date, inSameDayAs: store.today) {
            return PillieLocalization.string("global.status.completed", locale: locale)
        }
        let dateText = alarmAction.date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(locale)
        )
        return PillieLocalization.formatted(
            "today.next_action.date",
            locale: locale,
            arguments: dateText
        )
    }

    private func badgeText(
        alarmAction: DoseScheduleAction?,
        todayAction: DoseScheduleAction?,
        isTodayTaken: Bool,
        isTodayPassiveOrBreak: Bool
    ) -> String {
        if isTodayTaken {
            return PillieLocalization.string("global.status.completed", locale: locale)
        }
        if isTodayPassiveOrBreak {
            return PillieLocalization.string("global.status.break_day", locale: locale)
        }
        return alarmAction == nil
            ? PillieLocalization.string("today.empty.title", locale: locale)
            : PillieLocalization.string("today.next_action.title", locale: locale)
    }
}

#Preview {
    StatusCard()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
