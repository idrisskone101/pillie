//
//  StatusCard.swift
//  Pillie
//

import SwiftUI

struct StatusCard: View {
    /// Set only during the first-reminder hand-off in the status-card prototype (ENG-140).
    let onLogBeforeFirstReminder: (() -> Void)?

    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)

    var body: some View {
        let _ = store.protocolChangeVersion
        let isTodayTaken = store.isTodayTaken
        let isTodayNothingDue = store.isTodayNothingDue
        let alarmAction = store.alarmAction
        let todayAction = store.dueAction(on: store.today)
        let reminderTime = SettingsPresentation.time(
            hour: store.reminderHour,
            minute: store.reminderMinute,
            locale: locale
        )
        let method = (isTodayNothingDue ? todayAction : alarmAction)?.method ?? store.pack.method
        let actionTitle = StatusCardTitle.resolve(
            alarmAction: alarmAction,
            liveDay: store.today,
            now: store.civilDay,
            isTodayTaken: isTodayTaken,
            isTodayNothingDue: isTodayNothingDue,
            catchUp: store.openCatchUp,
            firstReminder: store.firstReminderHandoff
        ).localized(reminderTime: reminderTime, locale: locale)
        statusMainContent(
            method: method,
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
        method: ContraceptiveMethod,
        reminderTime: String,
        actionTitle: String,
        isTodayTaken: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(isTodayTaken ? PillieTheme.coral : PillieTheme.lavender)
                .frame(width: 48, height: 48)
                .overlay {
                    Group {
                        if isTodayTaken {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20))
                                .foregroundStyle(PillieTheme.textPrimary)
                        } else {
                            Image(method.iconImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    .transition(.opacity)
                    .animation(valueChangeAnimation, value: isTodayTaken)
                    .accessibilityHidden(true)
                }

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
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onLogBeforeFirstReminder {
                TookItCheckButton(action: onLogBeforeFirstReminder)
                    .transition(.opacity)
            }
        }
    }
}

private struct TookItCheckButton: View {
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .strokeBorder(PillieTheme.textPrimary, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .accessibilityHidden(true)
                Text(PillieLocalization.string("today.first_reminder.took_it", locale: locale))
                    .font(.pillie(12, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstReminderStatusTookIt")
    }
}

#Preview {
    StatusCard(onLogBeforeFirstReminder: nil)
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
