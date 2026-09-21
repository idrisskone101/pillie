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

    struct Input {
        let isRefillDue: Bool
        let isTodayTaken: Bool
        let todayDueAction: DoseScheduleAction?
        let isPlus: Bool
        let reduceMotionEnabled: Bool
    }

    static func resolve(_ input: Input) -> TodayActionState {
        if input.isRefillDue {
            return .refillDue
        }

        if input.isTodayTaken {
            return .completed
        }

        guard let todayDueAction = input.todayDueAction, !todayDueAction.isBreak else {
            return .noActionDue
        }

        return .dueAction(
            todayDueAction,
            requiresShakeConfirm: input.isPlus && !input.reduceMotionEnabled
        )
    }

    func localizedPrimaryLabel(locale: Locale = .current) -> String {
        switch self {
        case .refillDue:
            PillieLocalization.string("today.pack.start_new.confirm", locale: locale)
        case .completed:
            PillieLocalization.string("today.action.undo_complete", locale: locale)
        case .noActionDue:
            PillieLocalization.string("today.empty.title", locale: locale)
        case .dueAction(let action, _):
            DueActionCopy.localizedLabel(for: action, locale: locale)
        }
    }
}
