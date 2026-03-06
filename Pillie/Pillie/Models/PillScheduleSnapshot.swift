//
//  PillScheduleSnapshot.swift
//  Pillie
//

import Foundation

/// Read-only schedule snapshot used by UI surfaces that need synchronized
/// status/action rendering for the same day.
struct PillScheduleSnapshot {
    let date: Date
    let pack: PillPack
    let cycleDayIndex: Int
    let dueAction: DoseScheduleAction?
    let status: PillDay.Status?
    let actionType: PillDay.ActionType?

    /// Whether this day has any schedule context (action, passive, or break).
    var hasScheduleContext: Bool {
        dueAction != nil
    }

    /// Whether this day requires explicit user action (check-in).
    /// Passive active days and break days do NOT require action.
    var isDue: Bool {
        guard let action = dueAction else { return false }
        return action.type.requiresUserAction
    }

    /// Whether this day is a passive "wearing" day with no user action needed.
    var isPassiveActive: Bool {
        dueAction?.type.isPassiveActive ?? false
    }

    /// Whether this day is a break/off-week day.
    var isBreak: Bool {
        dueAction?.isBreak ?? false
    }
}
