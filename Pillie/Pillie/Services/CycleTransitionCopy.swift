//
//  CycleTransitionCopy.swift
//  Pillie
//

import Foundation

/// Pure value-type copy for the free Cycle Transition Notice (#123).
///
/// The notice is Pillie-authored, method-aware, and not user-customizable in v1 (it is
/// NOT part of the Custom Reminder Message perk). Copy is purely informational: it
/// explains why the daily reminders pause during the break/off week and names the date
/// the active phase resumes. It deliberately makes no medical claims (nothing about
/// protection, efficacy, or what is safe) — it only describes the schedule.
enum CycleTransitionCopy {
    static func title(for method: ContraceptiveMethod) -> String {
        PillieLocalization.string("notification.break_start.title")
    }

    /// Method-aware body naming the resume date. `calendar` is threaded through so the
    /// formatter resolves the date in the same calendar the schedule was planned with.
    static func body(
        for method: ContraceptiveMethod,
        resumeDate: Date,
        calendar: Calendar = .current
    ) -> String {
        switch method {
        case .pill:
            return PillieLocalization.string("notification.break_start.body")
        case .patch:
            return PillieLocalization.string("notification.break_start.patch.body")
        case .ring:
            return PillieLocalization.string("notification.break_start.ring.body")
        }
    }
}
