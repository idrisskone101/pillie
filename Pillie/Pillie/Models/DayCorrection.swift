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
                    currentOutcome: .breakDay
                )
            }
            return nil
        }

        guard snapshot.isDue else { return nil }

        let current: DayCorrectionOutcome
        switch snapshot.status {
        case .taken:
            current = .taken
        case .breakDay:
            current = .breakDay
        default:
            current = .unlogged
        }

        return DayCorrectionOptions(
            selectableOutcomes: [.taken, .unlogged, .breakDay],
            currentOutcome: current
        )
    }
}

struct DayCorrectionEvent: Equatable {
    let sequence: Int
    let date: Date
    let monthStart: Date
    let dayOfMonth: Int
}

enum HistoryDiscoveryAnnouncement {
    static let storageKey = "historyDayCorrectionDiscoveryDismissed"
}
