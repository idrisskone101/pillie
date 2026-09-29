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
        /// A missed patch or ring task Home can still log late.
        var catchUp: DoseScheduleAction? = nil
        var isCaughtUpToday = false
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

        return .dueAction(
            action,
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
