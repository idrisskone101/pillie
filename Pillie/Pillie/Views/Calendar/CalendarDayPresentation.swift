//
//  CalendarDayPresentation.swift
//  Pillie
//

import Foundation

enum CalendarDayRelation {
    case past
    case today
    case future
}

enum CalendarPatchSemanticStyle: Equatable {
    case invalid
    case neutral
    case patchApplied
    case plannedApplied
    case changedTaken
    case changedMissed
    case changedUpcoming
    case offWeek
    case plannedChange
    case plannedOffWeek
}

enum CalendarRingSemanticStyle: Equatable {
    case invalid
    case neutral
    case inserted
    case reinserted
    case missed
    case ringFree
    case plannedInserted
    case plannedReinserted
    case plannedRingFree
}

struct CalendarDayPresentation: Equatable {
    let method: ContraceptiveMethod
    let relation: CalendarDayRelation
    let status: PillDay.Status?
    let visualStatus: PillDay.Status?
    let actionType: PillDay.ActionType?
    let hasScheduleContext: Bool
    let isActionDay: Bool
    let isPassiveActive: Bool
    let isBreakDay: Bool
    let patchStyle: CalendarPatchSemanticStyle
    let ringStyle: CalendarRingSemanticStyle

    var isPatchMethod: Bool { method == .patch }
    var isRingMethod: Bool { method == .ring }
    var isToday: Bool { relation == .today }
    var isFutureDay: Bool { relation == .future }
    var showVisual: Bool { !isFutureDay && hasScheduleContext }

    var showsDefaultIndicator: Bool {
        isToday || isActionDay || isBreakDay
    }

    var defaultIndicatorOpacity: Double {
        guard showsDefaultIndicator else { return 0 }
        return isFutureDay ? 0.4 : 1
    }

    static func resolve(
        snapshot: PillScheduleSnapshot?,
        fallbackMethod: ContraceptiveMethod,
        relation: CalendarDayRelation
    ) -> CalendarDayPresentation {
        let method = snapshot?.pack.method ?? fallbackMethod
        let status = snapshot?.status
        let actionType = snapshot?.actionType
        let isFutureDay = relation == .future
        let visualStatus = isFutureDay ? nil : status

        return CalendarDayPresentation(
            method: method,
            relation: relation,
            status: status,
            visualStatus: visualStatus,
            actionType: actionType,
            hasScheduleContext: snapshot?.hasScheduleContext ?? false,
            isActionDay: snapshot?.isDue ?? false,
            isPassiveActive: snapshot?.isPassiveActive ?? false,
            isBreakDay: snapshot?.isBreak ?? false,
            patchStyle: method == .patch ? patchSemanticStyle(snapshot: snapshot, relation: relation) : .invalid,
            ringStyle: method == .ring ? ringSemanticStyle(snapshot: snapshot, relation: relation) : .invalid
        )
    }

    static func patchSemanticStyle(
        snapshot: PillScheduleSnapshot?,
        relation: CalendarDayRelation
    ) -> CalendarPatchSemanticStyle {
        guard let snapshot, snapshot.hasScheduleContext, snapshot.status != .noData else {
            return .invalid
        }

        let actionType = snapshot.actionType ?? snapshot.dueAction?.type

        switch relation {
        case .future:
            switch actionType {
            case .some(.patchChange), .some(.patchRemove):
                return .plannedChange
            case .some(.patchBreak):
                return .plannedOffWeek
            case .some(.patchActive):
                return .plannedApplied
            default:
                return snapshot.status == .breakDay ? .plannedOffWeek : .neutral
            }

        case .past, .today:
            switch actionType {
            case .some(.patchBreak):
                return .offWeek
            case .some(.patchActive):
                return .patchApplied
            case .some(.patchChange), .some(.patchRemove):
                switch snapshot.status {
                case .taken:
                    return .changedTaken
                case .missed:
                    return .changedMissed
                case .upcoming:
                    return .changedUpcoming
                case .breakDay:
                    return .offWeek
                case .noData, nil:
                    return relation == .past ? .changedMissed : .changedUpcoming
                }
            default:
                return snapshot.status == .breakDay ? .offWeek : .neutral
            }
        }
    }

    static func ringSemanticStyle(
        snapshot: PillScheduleSnapshot?,
        relation: CalendarDayRelation
    ) -> CalendarRingSemanticStyle {
        guard let snapshot, snapshot.hasScheduleContext, snapshot.status != .noData else {
            return .invalid
        }

        let actionType = snapshot.actionType ?? snapshot.dueAction?.type

        switch relation {
        case .future:
            switch actionType {
            case .some(.ringBreak):
                return .plannedRingFree
            case .some(.ringReinsert):
                return .plannedReinserted
            case .some(.ringInsert), .some(.ringRemove), .some(.ringActive):
                return .plannedInserted
            default:
                return snapshot.status == .breakDay ? .plannedRingFree : .neutral
            }

        case .past, .today:
            if snapshot.status == .missed {
                return .missed
            }
            switch actionType {
            case .some(.ringBreak):
                return .ringFree
            case .some(.ringReinsert):
                return .reinserted
            case .some(.ringInsert), .some(.ringRemove), .some(.ringActive):
                return .inserted
            default:
                return snapshot.status == .breakDay ? .ringFree : .neutral
            }
        }
    }
}
