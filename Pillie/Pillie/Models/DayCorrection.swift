//
//  DayCorrection.swift
//  Pillie
//

import Foundation

enum DayCorrectionOutcome: String, Equatable {
    case taken
    case unlogged
    case breakDay

    /// Suffix of the `history.dayCorrection.<key>.title` / `.subtitle` strings.
    var localizationKey: String {
        switch self {
        case .taken: "taken"
        case .unlogged: "unlogged"
        case .breakDay: "break"
        }
    }
}

struct DayCorrectionOptions: Equatable {
    let selectableOutcomes: [DayCorrectionOutcome]
    let currentOutcome: DayCorrectionOutcome

    func allows(_ outcome: DayCorrectionOutcome) -> Bool {
        selectableOutcomes.contains(outcome)
    }
}

/// A past calendar day the user may correct, resolved once by the grid so the
/// sheet never re-derives it. Plain values only: the store re-validates
/// against a fresh snapshot when the correction is applied.
struct HistoryEditableDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    /// The method of the pack that owns this day, which may differ from the
    /// current pack's method.
    let method: ContraceptiveMethod
    let options: DayCorrectionOptions
}

enum DayCorrectionPolicy {
    /// Which outcomes a day can be corrected to, or nil when the day is inert.
    static func options(
        for snapshot: PillScheduleSnapshot,
        relation: CalendarDayRelation
    ) -> DayCorrectionOptions? {
        guard relation == .past,
              let due = snapshot.dueAction,
              snapshot.status != .noData,
              !snapshot.isPassiveActive else {
            return nil
        }
        // Reinserting the ring starts a new cycle (`markActionAsTaken`), which a
        // single-day rewrite cannot reproduce. Both faces of that day stay
        // read-only: the missed reinsert on the old pack (due `.ringReinsert`)
        // and the auto-started pack's day 1, whose schedule says `.ringInsert`
        // but whose record was written as `.ringReinsert`.
        guard due.type != .ringReinsert, snapshot.actionType != .ringReinsert else { return nil }

        switch (due.type.isBreakType, snapshot.status) {
        case (true, .taken), (true, .missed):
            // A stale record on a day that later became a scheduled break
            // (a cycle-day shift in Settings). The only sane repair is Break.
            return DayCorrectionOptions(
                selectableOutcomes: [.breakDay],
                currentOutcome: currentOutcome(for: snapshot.status)
            )
        case (true, _):
            return nil
        case (false, _):
            guard snapshot.isDue else { return nil }
            return DayCorrectionOptions(
                selectableOutcomes: [.taken, .unlogged, .breakDay],
                currentOutcome: currentOutcome(for: snapshot.status)
            )
        }
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
