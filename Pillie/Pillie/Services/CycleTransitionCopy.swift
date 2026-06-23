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
    private static let resumeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter
    }()

    static func title(for method: ContraceptiveMethod) -> String {
        switch method {
        case .pill:
            return "Your break week starts today"
        case .patch:
            return "Your patch-free week starts today"
        case .ring:
            return "Your ring-free week starts today"
        }
    }

    /// Method-aware body naming the resume date. `calendar` is threaded through so the
    /// formatter resolves the date in the same calendar the schedule was planned with.
    static func body(
        for method: ContraceptiveMethod,
        resumeDate: Date,
        calendar: Calendar = .current
    ) -> String {
        let formatter = resumeDateFormatter
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let resume = formatter.string(from: resumeDate)

        switch method {
        case .pill:
            return "No pill reminders during your break — this is expected. Your next pack starts \(resume)."
        case .patch:
            return "No patch reminders this week — this is expected. Your next patch starts \(resume)."
        case .ring:
            return "No ring reminders this week — this is expected. Your next ring starts \(resume)."
        }
    }
}
