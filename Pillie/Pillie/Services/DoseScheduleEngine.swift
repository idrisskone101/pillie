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
        switch type {
        case .pillActive:
            return "Pillie check-in"
        case .patchChange:
            return "Patch check-in"
        case .patchRemove:
            return "Patch check-in"
        case .ringInsert:
            return "Ring check-in"
        case .ringRemove:
            return "Ring check-in"
        case .ringReinsert:
            return "Ring check-in"
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            return "Pillie check-in"
        }
    }

    var reminderBody: String {
        switch type {
        case .pillActive:
            return "A quick moment to take your pill and log it."
        case .patchChange:
            return "Time to switch your patch when you're ready."
        case .patchRemove:
            return "Time to remove your patch when you're ready."
        case .ringInsert:
            return "Time to insert your ring when you're ready."
        case .ringRemove:
            return "Time to remove your ring when you're ready."
        case .ringReinsert:
            return "Time to reinsert your ring when you're ready."
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            return "Open Pillie when you're ready."
        }
    }

    /// Title for the end-of-day Last Call backstop. Pillie-authored, single title across
    /// methods; the body carries the method-specific action.
    var lastCallReminderTitle: String {
        "Last call for today"
    }

    /// Method-aware body for the Last Call backstop. Obeys the medical-claims copy rules
    /// — no "never miss", no "protect", no efficacy framing.
    var lastCallReminderBody: String {
        switch type {
        case .pillActive:
            return "The day's almost over — a good moment to take your pill and log it."
        case .patchChange:
            return "The day's almost over — a good moment to switch your patch and log it."
        case .patchRemove:
            return "The day's almost over — a good moment to remove your patch and log it."
        case .ringInsert:
            return "The day's almost over — a good moment to insert your ring and log it."
        case .ringRemove:
            return "The day's almost over — a good moment to remove your ring and log it."
        case .ringReinsert:
            return "The day's almost over — a good moment to reinsert your ring and log it."
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            return "The day's almost over — open Pillie when you're ready."
        }
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
            // Patch change schedule is anchored to startDate directly,
            // ignoring cycleDayAnchorIndex. This mirrors the ring approach
            // so that editing the cycle day in Settings never shifts the
            // next patch change date.
            let anchorStart = calendar.startOfDay(for: pack.startDate)
            let target = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: anchorStart, to: target).day ?? 0
            let scheduleDay = ((diff % 28) + 28) % 28 + 1

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
            // the removal date. Falls back to startDate when not yet pinned.
            let anchorDate = pack.ringInsertionDate ?? pack.startDate
            let anchorStart = calendar.startOfDay(for: anchorDate)
            let target = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: anchorStart, to: target).day ?? 0
            let ringDay = ((diff % 28) + 28) % 28 + 1

            let type: PillDay.ActionType
            switch ringDay {
            case 1:
                type = diff > 0 ? .ringReinsert : .ringInsert
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
