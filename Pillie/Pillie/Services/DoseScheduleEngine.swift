//
//  DoseScheduleEngine.swift
//  Pillie
//

import Foundation

struct DoseScheduleAction: Hashable {
    let date: Date
    let type: PillDay.ActionType
    let method: ContraceptiveMethod
    let cycleDay: Int
    let cycleLength: Int

    var isBreak: Bool {
        type.isBreakType
    }

    var actionTitle: String {
        type.title
    }

    var ctaLabel: String {
        switch type {
        case .pillActive:
            return "Mark Pill as Taken"
        case .pillBreak:
            return "Log Break Day"
        case .patchChange:
            return "Mark Patch Changed"
        case .patchRemove:
            return "Mark Patch Removed"
        case .patchActive:
            return "Patch Active"
        case .patchBreak:
            return "Log Off Week"
        case .ringInsert:
            return "Mark Ring Inserted"
        case .ringRemove:
            return "Mark Ring Removed"
        case .ringReinsert:
            return "Mark Ring Reinserted"
        case .ringActive:
            return "Ring Active"
        case .ringBreak:
            return "Log Off Week"
        }
    }

    var badgeLabel: String {
        switch type {
        case .pillActive:
            return "PILL"
        case .pillBreak, .patchBreak, .ringBreak:
            return "BREAK"
        case .patchChange, .patchRemove, .patchActive:
            return "PATCH"
        case .ringInsert:
            return "INSERT"
        case .ringRemove:
            return "REMOVE"
        case .ringReinsert:
            return "REINSERT"
        case .ringActive:
            return "RING"
        }
    }

    var reminderTitle: String {
        localizedReminderTitle()
    }

    func localizedReminderTitle(locale: Locale = .current) -> String {
        let key: String
        switch method {
        case .pill: key = "notification.reminder.pill.title"
        case .patch: key = "notification.reminder.patch.title"
        case .ring: key = "notification.reminder.ring.title"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    var reminderBody: String {
        localizedReminderBody()
    }

    func localizedReminderBody(locale: Locale = .current) -> String {
        let key: String
        switch method {
        case .pill: key = "notification.reminder.pill.body"
        case .patch: key = "notification.reminder.patch.body"
        case .ring: key = "notification.reminder.ring.body"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    func localizedFollowUpTitle(locale: Locale = .current) -> String {
        PillieLocalization.string("notification.followup.title", locale: locale)
    }

    func localizedFollowUpBody(locale: Locale = .current) -> String {
        PillieLocalization.string("notification.followup.body", locale: locale)
    }

    func localizedFinalTitle(locale: Locale = .current) -> String {
        PillieLocalization.string("notification.final.title", locale: locale)
    }

    func localizedFinalBody(locale: Locale = .current) -> String {
        PillieLocalization.string("notification.final.body", locale: locale)
    }

    /// Title for the end-of-day Last Call backstop. Pillie-authored, single title across
    /// methods; the body carries the method-specific action.
    var lastCallReminderTitle: String {
        localizedFinalTitle()
    }

    /// Method-aware body for the Last Call backstop. Obeys the medical-claims copy rules
    /// — no "never miss", no "protect", no efficacy framing.
    var lastCallReminderBody: String {
        localizedFinalBody()
    }
}

enum DoseScheduleEngine {
    /// Pure due-action generator. Status inference belongs to `PillStore` so all
    /// UI surfaces consume one synchronized read model.
    static func dueAction(on date: Date, pack: PillPack, calendar: Calendar = .current) -> DoseScheduleAction? {
        let cycleDay = pack.cycleDayIndex(on: date, calendar: calendar) + 1
        switch pack.method {
        case .pill:
            let type: PillDay.ActionType = cycleDay <= pack.activeDays ? .pillActive : .pillBreak
            return DoseScheduleAction(
                date: calendar.startOfDay(for: date),
                type: type,
                method: .pill,
                cycleDay: cycleDay,
                cycleLength: pack.cycleLength
            )

        case .patch:
            // Patch schedule days come from the same cycleDayIndex math as the
            // calendar and cycle strip, so change/remove days honor a mid-cycle
            // start (cycleDayAnchorIndex > 0 after a method switch) instead of
            // silently restarting the 1/8/15 rhythm at the pack's startDate.
            let scheduleDay = cycleDay

            let type: PillDay.ActionType
            if [1, 8, 15].contains(scheduleDay) {
                type = .patchChange
            } else if scheduleDay == pack.activeDays + 1 {
                type = .patchRemove
            } else if scheduleDay <= pack.activeDays {
                type = .patchActive
            } else {
                type = .patchBreak
            }
            return DoseScheduleAction(
                date: calendar.startOfDay(for: date),
                type: type,
                method: .patch,
                cycleDay: scheduleDay,
                cycleLength: 28
            )

        case .ring:
            // Ring actions are anchored to ringInsertionDate (pinned at first
            // check-in) so that editing the cycle day in Settings never shifts
            // the removal date. While unpinned this follows cycleDayIndex —
            // startDate plus the mid-cycle anchor — so the schedule and the
            // displayed cycle day always agree.
            let ringDay = cycleDay
            let elapsed = pack.elapsedCycleDays(on: date, calendar: calendar)

            let type: PillDay.ActionType
            switch ringDay {
            case 1:
                type = elapsed > 0 ? .ringReinsert : .ringInsert
            case 2...21:
                type = .ringActive
            case 22:
                type = .ringRemove
            case 23...28:
                type = .ringBreak
            default:
                type = .ringActive
            }
            return DoseScheduleAction(
                date: calendar.startOfDay(for: date),
                type: type,
                method: .ring,
                cycleDay: ringDay,
                cycleLength: 28
            )
        }
    }

    static func dueActions(
        in range: ClosedRange<Date>,
        pack: PillPack,
        calendar: Calendar = .current
    ) -> [DoseScheduleAction] {
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        guard start <= end else { return [] }

        var cursor = start
        var actions: [DoseScheduleAction] = []
        while cursor <= end {
            if let due = dueAction(on: cursor, pack: pack, calendar: calendar) {
                actions.append(due)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return actions
    }

    static func nextDueActions(
        from date: Date,
        limit: Int,
        pack: PillPack,
        calendar: Calendar = .current
    ) -> [DoseScheduleAction] {
        guard limit > 0 else { return [] }

        var cursor = calendar.startOfDay(for: date)
        var actions: [DoseScheduleAction] = []
        var safetyCounter = 0
        let maxDaysToScan = max(365, pack.cycleLength * max(2, limit))

        while actions.count < limit && safetyCounter < maxDaysToScan {
            if let due = dueAction(on: cursor, pack: pack, calendar: calendar),
               due.type.requiresUserAction {
                actions.append(due)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            safetyCounter += 1
        }
        return actions
    }
}
