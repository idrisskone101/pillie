//
//  RoutineDetailsSection.swift
//  Pillie
//
//  The method-specific section the Routine Basics Details screen shows (#77). A Pill
//  user chooses a regimen (21/7, 24/4, continuous, more…); a Patch or Ring user has a
//  fixed schedule instead, so they see their schedule rules rather than an irrelevant
//  pill-pack picker. Extracting the decision keeps the view's method branch testable.
//

import Foundation

enum RoutineDetailsSection: Equatable {
    /// Pill: pick the active/break regimen.
    case pillRegimen
    /// Patch / Ring: a fixed weekly/monthly schedule, no regimen choice.
    case fixedSchedule

    init(method: ContraceptiveMethod) {
        self = method == .pill ? .pillRegimen : .fixedSchedule
    }
}
