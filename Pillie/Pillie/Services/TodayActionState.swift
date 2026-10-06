//
//  TodayActionState.swift
//  Pillie
//

import Foundation

enum TodayActionState: Equatable {
    case refillDue
    case completed
    case noActionDue
    case dueAction(DoseScheduleAction, requiresShakeConfirm: Bool)
    /// A dose is due but the first reminder has not fired: the reminder is the
    /// prompt, so logging is a quiet "Took it" for someone who already did.
    case dueActionAwaitingFirstReminder(DoseScheduleAction, requiresShakeConfirm: Bool)

    struct Input {
        let isRefillDue: Bool
        let isTodayTaken: Bool
        let todayDueAction: DoseScheduleAction?
        let isPlus: Bool
        let reduceMotionEnabled: Bool
        /// A missed patch or ring task Home can still log late.
        var catchUp: DoseScheduleAction? = nil
        var isCaughtUpToday = false
        var awaitsFirstReminder = false
    }

    static func resolve(_ input: Input) -> TodayActionState {
        if input.isRefillDue {
            return .refillDue
        }

        if input.isTodayTaken || input.isCaughtUpToday {
            return .completed
        }

        let todayDueAction = input.todayDueAction.flatMap { $0.type.requiresUserAction ? $0 : nil }
        guard let action = todayDueAction ?? input.catchUp else {
            return .noActionDue
        }

        let requiresShakeConfirm = input.isPlus && !input.reduceMotionEnabled
        if input.awaitsFirstReminder, todayDueAction != nil {
            return .dueActionAwaitingFirstReminder(action, requiresShakeConfirm: requiresShakeConfirm)
        }
        return .dueAction(action, requiresShakeConfirm: requiresShakeConfirm)
    }

    func localizedPrimaryLabel(locale: Locale = PillieLocalization.appLocale) -> String {
        switch self {
        case .refillDue:
            PillieLocalization.string("today.pack.start_new.confirm", locale: locale)
        case .completed:
            PillieLocalization.string("today.action.undo_complete", locale: locale)
        case .noActionDue:
            PillieLocalization.string("today.empty.title", locale: locale)
        case .dueAction(let action, _):
            DueActionCopy.localizedLabel(for: action, locale: locale)
        case .dueActionAwaitingFirstReminder:
            PillieLocalization.string("today.first_reminder.took_it", locale: locale)
        }
    }
}
