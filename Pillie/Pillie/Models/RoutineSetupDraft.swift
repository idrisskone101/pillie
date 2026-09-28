//
//  RoutineSetupDraft.swift
//  Pillie
//
//  Value-type routine setup state shared by the onboarding view and its behavior
//  tests. It keeps progressive-disclosure presentation separate from the exact
//  values committed to PillStore.
//

import Foundation

struct RoutineSetupCommit: Equatable {
    let regimen: PillPack.PillRegimenPreset
    let customRegimen: PackRegimen?
    let cycleDay: Int
}

struct RoutineSetupDraft: Equatable {
    let method: ContraceptiveMethod
    private(set) var selectedRegimen: PillPack.PillRegimenPreset
    private(set) var customRegimen: PackRegimen
    private(set) var cycleDay: Int

    init(method: ContraceptiveMethod) {
        self.method = method
        self.selectedRegimen = .twentyOneSeven
        self.customRegimen = PillPack.defaultCustomRegimen
        self.cycleDay = 1
    }

    init(
        method: ContraceptiveMethod,
        activePack: PillPack,
        today: Date,
        calendar: Calendar = .current
    ) {
        self.method = method
        self.selectedRegimen = .twentyOneSeven
        self.customRegimen = PillPack.defaultCustomRegimen
        self.cycleDay = activePack.method == method
            ? activePack.cycleDayIndex(on: today, calendar: calendar) + 1
            : 1
        clampCycleDay()
    }

    var cycleLength: Int { 28 }

    mutating func selectPosition(_ position: CyclePosition) {
        cycleDay = position.cycleDay(in: cycleLength)
    }

    mutating func setExactCycleDay(_ day: Int) {
        cycleDay = min(max(1, day), max(1, cycleLength))
    }

    var commit: RoutineSetupCommit {
        RoutineSetupCommit(
            regimen: selectedRegimen,
            customRegimen: selectedRegimen == .custom ? customRegimen : nil,
            cycleDay: cycleDay
        )
    }

    private mutating func clampCycleDay() {
        cycleDay = min(max(1, cycleDay), max(1, cycleLength))
    }
}
