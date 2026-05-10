//
//  StatusCard.swift
//  Pillie
//

import SwiftUI

struct StatusCard: View {
    @Environment(PillStore.self) var store
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)
    private static let alarmDayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    var body: some View {
        let isTodayTaken = store.isTodayTaken
        let isTodayPassiveOrBreak = store.isTodayPassiveOrBreak
        let alarmAction = store.alarmAction
        let todayAction = store.dueAction(on: store.today)
        let reminderTime = store.nextReminderTime
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
                    .lineLimit(isTodayTaken ? 2 : 1)
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
            return todayAction?.actionTitle ?? "No action due"
        }

        guard let alarmAction else { return "No action due" }
        guard isTodayTaken else { return alarmAction.actionTitle }

        let nextAction = alarmAction.badgeLabel.lowercased()
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: store.today),
           calendar.isDate(alarmAction.date, inSameDayAs: tomorrow) {
            return "Taken today. Next \(nextAction) tomorrow at \(reminderTime)."
        }
        if calendar.isDate(alarmAction.date, inSameDayAs: store.today) {
            return "Taken today. Next \(nextAction) at \(reminderTime)."
        }
        let dayLabel = Self.alarmDayLabelFormatter.string(from: alarmAction.date)
        return "Taken today. Next \(nextAction) \(dayLabel) at \(reminderTime)."
    }

    private func badgeText(
        alarmAction: DoseScheduleAction?,
        todayAction: DoseScheduleAction?,
        isTodayTaken: Bool,
        isTodayPassiveOrBreak: Bool
    ) -> String {
        if isTodayTaken {
            return "TAKEN"
        }
        if isTodayPassiveOrBreak {
            return todayAction?.badgeLabel ?? "NONE"
        }
        return alarmAction?.badgeLabel ?? "NONE"
    }
}

#Preview {
    StatusCard()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
