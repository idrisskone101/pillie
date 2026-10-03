//
//  ProtocolEditorTypes.swift
//  Pillie
//

import Foundation

/// What the Settings schedule editor will save: a pill pack position or a
/// patch/ring dial position, each in the onboarding module's own selection type.
enum ScheduleDraft: Equatable {
    case pill(TodayPillSelection)
    case dial(RoutineDialSelection)

    /// The routine the store holds when the editor opens.
    struct Current {
        let method: ContraceptiveMethod
        let regimen: PackRegimen
        let cycleDayIndex: Int
        let isTodayTaken: Bool
    }

    /// The current method opens on today's position with today's answer from the
    /// store, so Save works without a tap. Another method starts unpicked.
    static func seeded(_ method: ContraceptiveMethod, from current: Current) -> ScheduleDraft {
        let isCurrent = method == current.method
        let answer: TodayPillPick.Answer = current.isTodayTaken ? .taken : .notYet

        guard let dialMethod = RoutineDialMethod(method) else {
            let pack = isCurrent ? PackChoice(current.regimen) : PackChoice(preset: .twentyOneSeven)
            guard isCurrent else { return .pill(TodayPillSelection(pack: pack)) }
            let dayIndex = min(max(current.cycleDayIndex, 0), pack.regimen.totalDays - 1)
            let asksQuestion = pack.regimen.day(atIndex: dayIndex).kind != .noPill
            let pick = TodayPillPick(pack: pack, dayIndex: dayIndex, answer: asksQuestion ? answer : nil)
            return .pill(pick.map { TodayPillSelection(restoring: $0) } ?? TodayPillSelection(pack: pack))
        }

        guard isCurrent else { return .dial(RoutineDialSelection(method: dialMethod)) }
        let cycleDay = min(max(current.cycleDayIndex + 1, 1), RoutineDialDay.cycleLength)
        let asksQuestion = RoutineDialDay.day(cycleDay, method: dialMethod).task != nil
        let pick = RoutineDialPick(method: dialMethod, cycleDay: cycleDay, answer: asksQuestion ? answer : nil)
        return .dial(pick.map { RoutineDialSelection(restoring: $0) } ?? RoutineDialSelection(method: dialMethod, cycleDay: cycleDay))
    }

    var method: ContraceptiveMethod {
        switch self {
        case .pill: .pill
        case .dial(let selection): selection.method.contraceptiveMethod
        }
    }

    /// Today's 1-based cycle day, or nil until a pill is tapped.
    var cycleDay: Int? {
        switch self {
        case .pill(let selection): selection.dayIndex.map { $0 + 1 }
        case .dial(let selection): selection.cycleDay
        }
    }

    var isComplete: Bool {
        switch self {
        case .pill(let selection): selection.pick != nil
        case .dial(let selection): selection.pick != nil
        }
    }

    var logsToday: Bool {
        switch self {
        case .pill(let selection): selection.pick?.logsADose ?? false
        case .dial(let selection): selection.pick?.logsAnAction ?? false
        }
    }

    var preset: PillPack.PillRegimenPreset {
        switch self {
        case .pill(let selection): selection.pack.preset
        case .dial: .twentyOneSeven
        }
    }

    var customRegimen: PackRegimen? {
        guard case .pill(let selection) = self, selection.pack.preset == .custom else { return nil }
        return selection.pack.regimen
    }
}
