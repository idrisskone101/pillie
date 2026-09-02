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

enum HistoryCoachMarkState {
    static let storageKey = "historyDayCorrectionCoachMarkDismissed"

    static func target(
        in snapshots: [Int: PillScheduleSnapshot],
        month: Date,
        today: Date
    ) -> Int? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        var monthComponents = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: monthComponents) else { return nil }

        var bestDay: Int?
        var bestDate: Date?

        for (day, snapshot) in snapshots {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: date)
            guard dayStart < todayStart else { continue }
            guard snapshot.isDue else { continue }
            guard snapshot.status == .missed else { continue }

            if bestDate == nil || dayStart > bestDate! {
                bestDate = dayStart
                bestDay = day
            }
        }

        return bestDay
    }
}
