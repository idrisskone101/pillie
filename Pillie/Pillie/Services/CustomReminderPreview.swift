//
//  CustomReminderPreview.swift
//  Pillie
//

import Foundation

/// Pure resolver for the live notification preview in the Reminder Messages editor (#111).
///
/// It returns exactly the *effective* copy that will fire by delegating to
/// `CustomReminderCopy.effective` — the same helper `NotificationManager` builds the real
/// notification from — so the preview can never diverge from what is scheduled (same caps,
/// same trimming, same blank→default fallback, same Plus gate).
///
/// The only preview-specific concern is choosing a representative *default*: the daily
/// reminder shows the current contraception method's default check-in copy, sourced straight
/// off `DoseScheduleAction.reminderTitle`/`reminderBody` (the notification's source of truth);
/// the follow-up reminder shows `NotificationManager`'s default retry copy.
enum CustomReminderPreview {
    /// Representative default Due Action Reminder title for the method's primary check-in.
    static func defaultDailyTitle(method: ContraceptiveMethod) -> String {
        representativeAction(for: method).reminderTitle
    }

    /// Representative default Due Action Reminder body for the method's primary check-in.
    static func defaultDailyBody(method: ContraceptiveMethod) -> String {
        representativeAction(for: method).reminderBody
    }

    /// Effective daily reminder title shown in the preview as the user types.
    static func dailyTitle(custom: String, method: ContraceptiveMethod, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: defaultDailyTitle(method: method),
            cap: CustomReminderCopy.titleCap,
            isPlus: isPlus
        )
    }

    /// Effective daily reminder body shown in the preview as the user types.
    static func dailyBody(custom: String, method: ContraceptiveMethod, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: defaultDailyBody(method: method),
            cap: CustomReminderCopy.bodyCap,
            isPlus: isPlus
        )
    }

    /// Effective follow-up (Auto-Reminder Retry) title shown in the preview.
    static func retryTitle(custom: String, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: NotificationManager.defaultRetryTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: isPlus
        )
    }

    /// Effective follow-up (Auto-Reminder Retry) body shown in the preview.
    static func retryBody(custom: String, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: NotificationManager.defaultRetryBody,
            cap: CustomReminderCopy.bodyCap,
            isPlus: isPlus
        )
    }

    /// Representative default Last Call title for the method's primary check-in. Sourced
    /// straight off `DoseScheduleAction.lastCallReminderTitle` (the notification's source
    /// of truth), so the preview never diverges from what fires.
    static func defaultLastCallTitle(method: ContraceptiveMethod) -> String {
        representativeAction(for: method).lastCallReminderTitle
    }

    /// Representative default Last Call body for the method's primary check-in.
    static func defaultLastCallBody(method: ContraceptiveMethod) -> String {
        representativeAction(for: method).lastCallReminderBody
    }

    /// Effective Last Call title shown in the preview as the user types.
    static func lastCallTitle(custom: String, method: ContraceptiveMethod, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: defaultLastCallTitle(method: method),
            cap: CustomReminderCopy.titleCap,
            isPlus: isPlus
        )
    }

    /// Effective Last Call body shown in the preview as the user types.
    static func lastCallBody(custom: String, method: ContraceptiveMethod, isPlus: Bool) -> String {
        CustomReminderCopy.effective(
            custom: custom,
            default: defaultLastCallBody(method: method),
            cap: CustomReminderCopy.bodyCap,
            isPlus: isPlus
        )
    }

    /// The primary check-in the method's user sees most often. Used only to source the
    /// representative default copy for the preview; the live notification still derives its
    /// default from the actual due action of the day, but both read the same
    /// `DoseScheduleAction.reminderTitle`/`reminderBody`, so the wording stays in lockstep.
    private static func representativeAction(for method: ContraceptiveMethod) -> DoseScheduleAction {
        let type: PillDay.ActionType
        switch method {
        case .pill: type = .pillActive
        case .patch: type = .patchChange
        case .ring: type = .ringInsert
        }
        return DoseScheduleAction(
            date: Date(timeIntervalSince1970: 0),
            type: type,
            method: method,
            cycleDay: 1,
            cycleLength: 28
        )
    }
}
