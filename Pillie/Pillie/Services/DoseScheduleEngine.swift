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
            return "Time for your pill!"
        case .pillBreak:
            return "Break day check-in"
        case .patchChange:
            return "Time to change your patch"
        case .patchRemove:
            return "Remove your patch today"
        case .patchActive:
            return "Patch is active"
        case .patchBreak:
            return "Off week"
        case .ringInsert:
            return "Insert your ring today"
        case .ringRemove:
            return "Remove your ring today"
        case .ringReinsert:
            return "Reinsert your ring today"
        case .ringActive:
            return "Ring is active"
        case .ringBreak:
            return "Off week"
        }
    }

    var reminderBody: String {
        "Cycle day \(cycleDay) of \(cycleLength). Open Pillie to log it."
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
            } else if scheduleDay == pack.activeDays {
                type = .patchRemove
            } else if scheduleDay < pack.activeDays {
                type = .patchActive
            } else {
                type = .patchBreak
            }
            return DoseScheduleAction(
                date: calendar.startOfDay(for: date),
                type: type,
                method: .patch,
                cycleDay: cycleDay,
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
                type = .ringInsert
            case 2...20:
                type = .ringActive
            case 21:
                type = .ringRemove
            case 22...27:
                type = .ringBreak
            case 28:
                type = .ringReinsert
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
