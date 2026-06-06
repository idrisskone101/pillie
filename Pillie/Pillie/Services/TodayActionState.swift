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

        guard let todayDueAction = input.todayDueAction else {
            return .noActionDue
        }

        return .dueAction(
            todayDueAction,
            requiresShakeConfirm: input.isPlus && !input.reduceMotionEnabled
        )
    }
}
