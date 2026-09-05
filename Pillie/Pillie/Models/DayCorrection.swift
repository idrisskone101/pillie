//
//  DayCorrection.swift
//  Pillie
//

import Foundation

enum DayCorrectionOutcome: String, CaseIterable, Equatable {
    case taken
    case unlogged
    case breakDay
}

struct DayCorrectionOptions: Equatable {
    let selectableOutcomes: [DayCorrectionOutcome]
    let currentOutcome: DayCorrectionOutcome

    func allows(_ outcome: DayCorrectionOutcome) -> Bool {
        selectableOutcomes.contains(outcome)
    }
}

enum DayCorrectionPolicy {
    static func options(
        for snapshot: PillScheduleSnapshot,
        relation: CalendarDayRelation
    ) -> DayCorrectionOptions? {
        guard relation == .past else { return nil }
        guard snapshot.hasScheduleContext else { return nil }
        guard snapshot.status != .noData else { return nil }
        guard !snapshot.isPassiveActive else { return nil }

        if snapshot.dueAction?.type.isBreakType == true {
            if snapshot.status == .breakDay {
                return nil
            }
            if snapshot.status == .taken || snapshot.status == .missed {
                return DayCorrectionOptions(
                    selectableOutcomes: [.breakDay],
                    currentOutcome: currentOutcome(for: snapshot.status)
                )
            }
            return nil
        }

        guard snapshot.isDue else { return nil }

        return DayCorrectionOptions(
            selectableOutcomes: [.taken, .unlogged, .breakDay],
            currentOutcome: currentOutcome(for: snapshot.status)
        )
    }

    private static func currentOutcome(for status: PillDay.Status?) -> DayCorrectionOutcome {
        switch status {
        case .taken:
            return .taken
        case .breakDay:
            return .breakDay
        default:
            return .unlogged
        }
    }
}
