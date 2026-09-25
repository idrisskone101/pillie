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
        let _ = store.protocolChangeVersion
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
        let actionTitle = StatusCardTitle.resolve(
            alarmAction: alarmAction,
            liveDay: store.today,
            now: store.civilDay,
            isTodayTaken: isTodayTaken,
            isTodayPassiveOrBreak: isTodayPassiveOrBreak
        ).localized(reminderTime: reminderTime, locale: locale)
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
                    .pillieAdaptiveLineLimit(regular: 2, minimumScaleFactor: 0.72)
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
}

#Preview {
    StatusCard()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
